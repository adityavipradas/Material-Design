for i = 1:20
    
    fname = sprintf('%d',i);
    xtr=imread(sprintf('%s.png', fname));
    xtr=rgb2gray(xtr);
    I=double(im2bw(xtr,0.3));
    fname2=sprintf('alloy2_%d',i+20);
    save(sprintf('%s.mat', fname2), 'I', '-v7.3');
end