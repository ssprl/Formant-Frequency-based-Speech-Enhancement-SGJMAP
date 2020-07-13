function [xfinal] = JMAPF(x,Srate)
[formant_freq] =[593.897011801963,1591.98279412604,2707.86579484156,3701.99968946960];
[bw]=2.*[46.80,108.31,116.88,62.09];
for for_len=1:length(formant_freq)
    formant_BWuc(for_len)   = formant_freq(for_len)+(bw(for_len)/2);
    formant_BWlc(for_len)   = formant_freq(for_len)-(bw(for_len)/2);
    forfreq_binsuc(for_len) = formant_BWuc(for_len)*1024./(Fs/2);
    forfreq_binslc(for_len) = formant_BWlc(for_len)*1024./(Fs/2);   
end
beta=1.2;
beta1=0.8;
% =============== Initialize variables ===============
SPU=1;
len=floor(20*Srate/1000); % Frame size in samples
if rem(len,2)==1, len=len+1; end;
PERC=50; % window overlap in percent of frame size
len1=floor(len*PERC/100);
len2=len-len1;

win=hanning(len);  % define window
win = win*len2/sum(win);  % normalize window for equal level output

nFFT=1024;
j=1;
noise_mean=zeros(nFFT,1);
noise_pow = zeros(nFFT,1);
for k=1:6
    noise_mean=noise_mean+abs(fft(win.*x(j:j+len-1),nFFT));
    j=j+len;
end
noise_mu=noise_mean/6;
noise_mu2=noise_mu.^2;
%--- allocate memory and initialize various variables
k=1;
img=sqrt(-1);
x_old=zeros(len1,1);
Nframes=floor(length(x)/len2)-1;
xfinal=zeros(Nframes*len2,1);
ensig=zeros(nFFT,1);
% --------------- Initialize parameters ------------
k=1;
aa=0.98;
eta= 0.15;
qk=0.3;
qkr=(1-qk)/qk;
ksi_min=10^(-25/10); % note that in Chap. 7, ref. [17], ksi_min (dB)=-15 dB is recommended
count = 0;
%===============================  Start Processing =======================================================

for n=1:Nframes
    tic
    insign=win.*x(k:k+len-1);
    
    %--- Take fourier transform of  frame
    %
    spec=fft(insign,nFFT);
    sig=abs(spec); % compute the magnitude
    sig2=sig.^2;
    
    gammak=min(sig2./noise_mu2,40);  % posteriori SNR
    if n==1
        ksi=aa+(1-aa)*max(gammak-1,0);
        
    else
        ksi=aa*Xk_prev./noise_mu2 + (1-aa)*max(gammak-1,0);

        ksi=max(ksi_min,ksi);  % limit ksi to -25 dB
    end
    
    log_sigma_k= gammak.* ksi./ (1+ ksi)- log(1+ ksi);
    vad_decision= sum( log_sigma_k)/nFFT;
    if (vad_decision< eta) % noise on

        noise_pow = noise_pow + noise_mu2;
        count = count+1;
    end

    noise_mu2 = noise_pow./count;

    
    vk=ksi.*gammak./(1+ksi);

    count1=0;
    for sig_in=1:length(sig)
        for forfreq_bin_in=1:length(forfreq_binslc)
            if ((floor(forfreq_binslc(forfreq_bin_in))<=sig_in)&&(sig_in<=ceil(forfreq_binsuc(forfreq_bin_in))))
                % if ( round(forfreq_binslc(1))<sig_in && (sig_in<round(forfreq_binsuc(1)))  || (round(forfreq_binslc(2))<sig_in) && (sig_in<round(forfreq_binsuc(2))) )%|| (round(forfreq_binslc(3))<sig_in) && (sig_in<round(forfreq_binsuc(3)))||(round(forfreq_binslc(4))<sig_in) && (sig_in<round(forfreq_binsuc(4)))||(round(forfreq_binslc(5))<sig_in) && (sig_in<round(forfreq_binsuc(5))))

                count1=count1+1;
                hw(sig_in)=(ksi(sig_in)+sqrt(ksi(sig_in).^2+(1+ksi(sig_in)/beta1).*ksi(sig_in)./gammak(sig_in)))./(2*(beta1+ksi(sig_in)));%% gain for formats
  
                break
            else
                
                hw(sig_in)=((ksi(sig_in)+sqrt(ksi(sig_in).^2+(1+ksi(sig_in)/beta).*ksi(sig_in)./gammak(sig_in)))./(2*(beta+ksi(sig_in))));%% gain for non formant bins
            end
        end
    end
    
    sig=sig.*hw';
    
    Xk_prev=sig.^2;  % save for estimation of a priori SNR in next frame
    
    xi_w= ifft( sig .* exp(img*angle(spec)),nFFT);
    
    xi_w= real( xi_w);
    
    xfinal(k:k+ len2-1)= x_old+ xi_w(1:len1);
    x_old= xi_w(len1+ 1: len);
    
    k=k+len2;
    jmp_time(n) = toc;
end
xfinal=xfinal/max(xfinal);