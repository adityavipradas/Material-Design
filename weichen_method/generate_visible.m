%%%% generate new 2nd layer hidden states

%% use gibbs sampling based on the conditional probabilities
nchannel = 1; % 2nd layer filter size
nimage = 100; %100 images
H = 200; % image height
W = 200; % image width
patch_size = 5;
margin_size = (patch_size-1)/2;
batch_size = 1000; % from each channel of each image, sample $batch_size$ patches

load(['./training_data/channel_conditional_model',num2str(patch_size),...
    '_batch',num2str(batch_size),'_0310.mat']);

% initialize a random hidden state matrix
% first, generate a $nchannel$ vector of activation rates
load('./training_data/mean_cov_channel.mat');
channel_rate = mvnrnd(state_mean_channel,state_cov_channel);
channel_rate(channel_rate<0) = 0;
channel_rate(channel_rate>1) = 1;
channel_rate = reshape(channel_rate, 1,1,numel(channel_rate));

% bernoulli draw for each hidden node
hidstate = (bsxfun(@le,rand(H,W,nchannel),channel_rate))*2-1; % randomize 2nd hidden state to {-1, 1}
% hidstate = (rand(H,W,nchannel)>0.5) + 0;
% hidstate = reshape(allhistate,H,W,nchannel)+ 0;
 
gibbs_iter = 1;
max_gibbs_iter = 100;
error_tol = 0.05;
error = 1;

vf_target = sum(sum(hidstate))/H/W; % volume fraction of the target image
vf = 0;
C = 0;

% input original image pixel id, output pixel id for the image with margins
image2margin = (1:H*W)'+...
    kron((H*margin_size+((2*margin_size)+(1:2:(2*W-1)))'*margin_size),ones(H,1));

patch_mesh_h = repmat((-margin_size:1:margin_size)',patch_size*H*W,1)+...
    repmat(kron((1:H)'+margin_size,ones(patch_size^2,1)),W,1);
patch_mesh_w = repmat(kron((-margin_size:1:margin_size)',ones(patch_size,1)),H*W,1)+...
    kron((1:W)'+margin_size,ones(patch_size^2*H,1));

% synthesis(hidstate)
display_network(reshape(hidstate(:,:,1),size(hidstate,1)*size(hidstate,2),1));
% while gibbs_iter <= max_gibbs_iter && error > error_tol
while abs(vf - vf_target)>error_tol && gibbs_iter <= max_gibbs_iter
    error = 0;
    fprintf('%%%%%%%%%%%%%%%%%%%% GIBBS ITER %%%%%%%%%%%%%%%%%%%%%');
    for c = 1:nchannel
        fprintf('%%%%%%%%%%%%%%%%%%%% channel %%%%%%%%%%%%%%%%%%%%%');
        pic = rand(H+2*margin_size,W+2*margin_size);
        pic((1:H)+margin_size,(1:W)+margin_size) = hidstate(:,:,c);
        
        count = 1;
        for w = 1:W
            for h = 1:H
                patch_sampled_h = patch_mesh_h((count-1)*patch_size^2+(1:patch_size^2));
                patch_sampled_w = patch_mesh_w((count-1)*patch_size^2+(1:patch_size^2));
                count = count + 1;

                id = sub2ind(size(pic),patch_sampled_h,patch_sampled_w);
                hx = pic(id);
                hx((patch_size^2+1)/2:end) = [];
                
                vx = reshape(hidstate(h,w,[1:c-1,c+1:end]),nchannel-1,1);
                
                x = [hx;vx];
                
                [predicted_label, accuracy, prob] = ...
                    svmpredict(sparse(hidstate(h,w,c)),sparse(x'),models{c}, sprintf('-b 1'));
                id = models{c}.Label==1; % for white
                if rand < prob(id) + C*sqrt(prob(id)*(1-prob(id)))
                    hidstate(h,w,c) = 1;
                else
                    hidstate(h,w,c) = -1;
                end
                pic((1:H)+margin_size,(1:W)+margin_size) = hidstate(:,:,c);
                error = error + (100-accuracy)/100;
            end
        end
    end
    error = error/nchannel/W/H;
    
    % update C to match volumn fraction
    vf = sum(sum((hidstate+1)/2))/H/W;
    if models{c}.Label(1)==1
        sign = 1;
    else
        sign = -1;
    end
    C = C-0.1*sign*(vf-vf_target);
    
%     synthesis(hidstate);
    display_network(reshape(hidstate(:,:,1),size(hidstate,1)*size(hidstate,2),1));
    
    gibbs_iter = gibbs_iter + 1;
end

% display_network(reshape(hidstate(:,:,6),size(hidstate,1)*size(hidstate,2),1));
% synthesis(hidstate)
