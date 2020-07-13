//
//  ViewController.m
//  CoreAudio
//  cJMAP Speech Enhancement

//  04/04/17.
//  Created by
//	Nikhil Shankar
//   Chandan K A Reddy
// 	 Ram Charan Chandra Shekar


// 	Copyright © 2017
//	Statistical Signal Processing Laboratory, University Of Texas @ Dallas.
// 	All rights reserved.

#import "ViewController.h"
#import "FIR.h"

#define kOutputBus 0
#define kInputBus 1
#define SHORT2FLOAT 1/32768.0
#define FLOAT2SHORT 32768.0;
#define FrameSize 256
#define SamplingFrequency 48000
#ifndef min
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif
int nFFT=1024;
//static float endSamples[3] = {0,0,0};
//int FFT=1024;
//static float *magnitudeRight =(float*)calloc(nFFT/2, sizeof(float));
//static float *magnitudeLeft =(float*)calloc(nFFT/2, sizeof(float));
static float *noise_mean = (float*)calloc(nFFT, sizeof(float));
static float *noise_mu2 = (float*)calloc(nFFT, sizeof(float));
static float *sig2 = (float*)calloc(nFFT, sizeof(float));
static float *gammak = (float*)calloc(nFFT, sizeof(float));
static float *ksi = (float*)calloc(nFFT, sizeof(float));
static float *Xk_prev = (float*)calloc(nFFT, sizeof(float));
static float *log_sigma_k = (float*)calloc(nFFT, sizeof(float));
static float *noise_pow = (float*)calloc(nFFT, sizeof(float));
static float *vk = (float*)calloc(nFFT, sizeof(float));
static float *hw = (float*)calloc(nFFT, sizeof(float));
static float *evk = (float*)calloc(nFFT, sizeof(float));
static float *Lambda = (float*)calloc(nFFT, sizeof(float));
static float *pSAP = (float*)calloc(nFFT, sizeof(float));
static float* ensig = ( float *)calloc(nFFT, sizeof( float));
static float* HPF = ( float*)calloc(2*(nFFT), sizeof( float));
static float* H = ( float*)calloc((nFFT), sizeof( float));
static float *fftmagoutput = (float*)calloc(nFFT, sizeof(float));
//static float *phase = (float*)calloc(nFFT, sizeof(float));
//static float *h=(float*)calloc(nFFT,sizeof(float));
//long double* nsig = (long double *)calloc(nFFT, sizeof(long double));
float PRT;
float N;
float aa = 0.98;
float eta = 0.15;
float beta=0.5;
float beta1=0.5;
float max;
float ksi_min = (float)pow(10,((float)-25 /(float)10));
float sum_log_sigma_k = 0;
float vad_decision;
float qk = 0.3;
float qkr = (1 - qk) / qk;;
//float epsilon =  (float)pow(8.854,-12);
float epsilon = 0.001;
float total_noisepower=0;
float total_speechpower=0;
//float SNR_db;
char SNR_db_char;
int count=0;
int SPU = 0;
static float SNR_db;
//float *magnitudeLeft, *magnitudeRight, *phaseLeft, *phaseRight, *fifoOutput;
//float sum_ensig;
//float beta;
int on;
int frameCounter=0;
float snr_counter=0;
float sum_SNR=0;
float snr_avg;
Transform *X;
Transform *Y;
int k=1;
int len = 512;
int len1=256;
int len2=256;


static float *win = (float*)malloc(nFFT* sizeof(float));
static float *sys_win = (float*)malloc(FrameSize* sizeof(float));




AURenderCallbackStruct callbackStruct;
AudioUnit au;
AudioBuffer tempBuffer;

@interface ViewController ()

@end

@implementation ViewController

@synthesize betaSlider;
@synthesize EnhancedSwitch;
@synthesize betaLabel;
@synthesize beta1Slider;
@synthesize beta1Label;
@synthesize formants;
@synthesize formantsLabel;

-(void) updateBeta{
    x=betaSlider.value;
    y=beta1Slider.value;
     betaLabel.text=[ NSString stringWithFormat:@"%f",x];
     beta1Label.text= [NSString stringWithFormat:@"%f",y];
    
}
-(void) updateFormants{
    formantsLabel.text=[ NSString stringWithFormat:@"%f",0.5];
    
}


// PLAYBACK
static OSStatus playbackCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    // assigning values to buffer
    for (int i=0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer buffer = ioData->mBuffers[i];
        UInt32 size = min(buffer.mDataByteSize, tempBuffer.mDataByteSize);
        memcpy(buffer.mData, tempBuffer.mData, size);
        buffer.mDataByteSize = size;
    }
    return noErr;
}


//RECORDING
static OSStatus recordingCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlags,const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    
    AudioBuffer buffer;
    ViewController* view = (__bridge ViewController *)(inRefCon);
    
    buffer.mNumberChannels = 1;
    buffer.mDataByteSize = inNumberFrames * 2;
    buffer.mData = malloc( inNumberFrames * 2 );
    
    //buffer is put in a AudioBufferList
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0] = buffer;
    
    //obtaining recorded samples
    AudioUnitRender(au, ioActionFlags, inTimeStamp,inBusNumber,inNumberFrames,&bufferList);
    
    [view AudioProcessignSE:&bufferList];
    // printf("%f\n",buffer);
    
    return noErr;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    betaLabel.text = @"0";
    beta1Label.text= @"0";
    // core audio different mode selection
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error: NULL];
    [[AVAudioSession sharedInstance] setMode: AVAudioSessionModeMoviePlayback error:NULL];
    [[AVAudioSession sharedInstance] setPreferredSampleRate:SamplingFrequency error:NULL];
    [[AVAudioSession sharedInstance]
     setPreferredIOBufferDuration:(float)FrameSize/(float)SamplingFrequency error:NULL];
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (AudioComponentInstanceNew(component, &au) != 0) abort();
    
    //Enable IO for playback
    UInt32 value = 1;
    if (AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &value,
                             sizeof(value))) abort();
    value = 1;
    if (AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &value,
                             sizeof(value))) abort();
    
    
    // Describe audio format
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 0;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    
    //Apply format
    if (AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat,
                             sizeof(audioFormat))) abort();
    if (AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat,
                             sizeof(audioFormat))) abort();
    // Set input callback
    
    callbackStruct.inputProc = recordingCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    AudioUnitSetProperty(au, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus,  &callbackStruct, sizeof(callbackStruct));
    
    // Set output callback
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    AudioUnitSetProperty(au, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus,&callbackStruct, sizeof(callbackStruct));
    tempBuffer.mNumberChannels = 1;
    tempBuffer.mDataByteSize = FrameSize * 2;
    tempBuffer.mData = malloc( FrameSize * 2 );
    AudioUnitInitialize(au);
    AudioOutputUnitStart(au);
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Speech enhancemnet algorithm
-(void) AudioProcessignSE: (AudioBufferList*) bufferList{
    AudioBuffer sourceBuffer = bufferList->mBuffers[0];
    
    
    // selecting a window
    for (int i = 0; i < nFFT; i++)
    {
       win[i] = 0.5 * (1 - cosf(2 * M_PI*(i + 1) / (nFFT + 1)));
    }
    for (int i = 0; i < FrameSize; i++)
    {
        sys_win[i] = 1 / (win[i] + win[i + FrameSize]);
    }
    
    double formant_freq[4] ={593.897011801963,1591.98279412604,2707.86579484156,3701.99968946960};
    double bw[4]={46.80,108.31,116.88,62.09};
    
    double *formant_BWuc = (double*)malloc(4*sizeof(double));
    double *formant_BWlc = (double*)malloc(4*sizeof(double));
    double *forfreq_binsuc = (double*)malloc(4*sizeof(double));
    double *forfreq_binslc = (double*)malloc(4*sizeof(double));
    
    
    //printf("%d\n",sizeof(formant_freq));
    for (int for_len=0;for_len<4;for_len++)
    {
        
        formant_BWuc[for_len]   = formant_freq[for_len]+(bw[for_len]/2);
        formant_BWlc[for_len ]   = formant_freq[for_len ]-(bw[for_len]/2);
        forfreq_binsuc[for_len] = formant_BWuc[for_len]*1024./(SamplingFrequency/2);
        forfreq_binslc[for_len ] = formant_BWlc[for_len ]*1024./(SamplingFrequency/2);
       // printf("%f\n",forfreq_binslc[for_len]);
        
    }
    

    
//initializing
    static short *buffer = (short*)calloc(sourceBuffer.mDataByteSize/sizeof(short), sizeof(short));
    static short *output = (short*)calloc(sourceBuffer.mDataByteSize/sizeof(short), sizeof(short));
   //static float *phase = (float*)calloc(nFFT, sizeof(float));
    static float *input = (float*)calloc(FrameSize, sizeof(float));
    static float *float_output = (float*)calloc(nFFT, sizeof(float));
   // static float *input1 = (float*)calloc(nFFT, sizeof(float));
   // static float *store_buffer = (float*)calloc(FrameSize, sizeof(float));
    static float *output_final = (float*)calloc(FrameSize, sizeof(float));
    static float *output_old = (float*)calloc(FrameSize, sizeof(float));
    static float *in_buffer = (float*)calloc(nFFT, sizeof(float));
    static float *in_prev = (float*)calloc(FrameSize, sizeof(float));
    //static float *float_output1 = (float*)calloc(nFFT, sizeof(float));

    memcpy(buffer, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);
    
    //storing input
    for (int i = 0; i < FrameSize; i++) {
        input[i] = buffer[i] * SHORT2FLOAT;
       // printf("%f\n",input[i]);
    }
 if(on==0)
    {
        for(int i =0;i<FrameSize;i++)
        {
        float_output[i]=input[i]*0.7;
    }
        //fir(input,float_output,FrameSize);
    }
    
    //converting to frequency domain
    X=newTransform(nFFT);
    Y=newTransform(nFFT);
    
    X->doTransform(X,in_buffer);
    for(int i=0;i<nFFT;i++)
    {
        // float_output[i]=Y->real[i];
        //printf("%f\n",X->real[i]);
    }
    transformMagnitude(X, fftmagoutput);

 if(on==1)
    {
        frameCounter++;
        for(int i =0;i<FrameSize;i++)
        {
            in_buffer[i]=in_prev[i] * win[i];
            in_prev[i]=input[i];
            in_buffer[i+FrameSize]=input[i] * win[i+FrameSize];
        }

        for(int i =0;i<nFFT;i++)
        {
            //printf("%f %d\n",input1[i],i);
        }
        float total_noisepower=0;
        float total_speechpower=0;
        float sum_ensig = 0;
        float sum_nsig = 0;
        
        
        // beta variable
        beta=x;
        beta1=y;
        if (beta==0)
        {
            beta=0.5;
        }
        
        if(beta1==0)
        {
            beta1=0.5;
        }
        
        
       // learning algorithm
            if(frameCounter<=6)
            {
                for (int i = 0; i < nFFT; i++)
                {
                noise_mean[i] += fftmagoutput[i];
               //printf("%f\n",noise_mean[i]);
                }
            }
        
        if(frameCounter==7)
        {
            for (int i = 0; i < nFFT; i++)
           {
                noise_mu2[i]=pow(noise_mean[i]/7,2);
                //printf("%f\n",noise_mu2[i]);

            }
        }
        if(frameCounter>=7)
        {
            for (int i = 0; i < nFFT; i++)
            {
                sig2[i] = pow(fftmagoutput[i], 2);
            
            
               if( noise_mu2[i]==0)
                {
              noise_mu2[i] = noise_mu2[i] + epsilon;
              }
                gammak[i] = sig2[i] / noise_mu2[i] < 40 ? sig2[i] / noise_mu2[i] : 40;
               // printf("%f\n",gammak[i]);
            
            if (frameCounter == 7)
            {
               // for (int i = 0; i < nFFT; i++) {
                    max = gammak[i] - 1 > 0 ? gammak[i] - 1 : 0;
                    ksi[i] = aa + (1 - aa) * max;
                    // printf("%f\n",ksi[i]);
           // }
            }
            else
            {
               
                    max = gammak[i] - 1 > 0 ? gammak[i] - 1 : 0;
                    ksi[i] = aa * (Xk_prev[i] / noise_mu2[i]) + (1 - aa) * max;
                    ksi[i] = ksi_min > ksi[i] ? ksi_min : ksi[i];
                    // printf("%f\n",Xk_prev[i]);
                }
            
            
                sum_log_sigma_k = 0;
                log_sigma_k[i] = gammak[i] * ksi[i] / (1 + ksi[i]) - log(1 + ksi[i]);
            if(log_sigma_k[i]<100)
            {
            sum_log_sigma_k += log_sigma_k[i];
            }
                
            }
            // printf("%f\n",sum_log_sigma_k);
            vad_decision = sum_log_sigma_k / (nFFT);
            
            //__android_log_print(ANDROID_LOG_VERBOSE, "MyApp", "The value of SNR_db is %f",vad_decision );
            if (vad_decision < eta)// % noise on
            {
                count = count + 1;
                //printf("%f\n",ksi[i]);
                for (int i = 0; i < nFFT; i++)
                {
                    noise_pow[i] = noise_pow[i] + noise_mu2[i];
                    noise_mu2[i] = noise_pow[i] / count;
                }
            }
            for (int i = 0; i < nFFT; i++)
            {
                vk[i] = ksi[i] * gammak[i] / (1 + ksi[i]);
               // int beta2 = 1;
               // int beta3 =3;
                int count1=0;
                for (int sig_in=0; sig_in<1024;sig_in++)
                {
                    for (int forfreq_bin_in=0; forfreq_bin_in<4; forfreq_bin_in++)
                    {
                        if ((floor(forfreq_binslc[forfreq_bin_in])<=sig_in)&&(sig_in<=ceil(forfreq_binsuc[forfreq_bin_in])))
                            //if ( round(forfreq_binslc(1))<sig_in && (sig_in<round(forfreq_binsuc(1)))  || (round(forfreq_binslc(2))<sig_in) && (sig_in<round(forfreq_binsuc(2))) )%|| (round(forfreq_binslc(3))<sig_in) && (sig_in<round(forfreq_binsuc(3)))||(round(forfreq_binslc(4))<sig_in) && (sig_in<round(forfreq_binsuc(4)))||(round(forfreq_binslc(5))<sig_in) && (sig_in<round(forfreq_binsuc(5))))
                            //hw(sig_in)=1;
                        {
                            count1=count1+1;
                        hw[i] = (ksi[i] + sqrt(pow(ksi[i], 2) + (1 + ksi[i] / beta) * ksi[i] / (gammak[i]+epsilon))) / (2 * (beta + ksi[i]));
                            
                        break;
                    }
                            else
                            {
                            hw[i] = (ksi[i] + sqrt(pow(ksi[i], 2) + (1 + ksi[i] / beta1) * ksi[i] / (gammak[i]+epsilon))) / (2 * (beta1 + ksi[i]));
                            }

                    }
                }
                //printf("%f\n",hw[i]);

           // determining SE gain
              // hw[i] = (ksi[i] + sqrt(pow(ksi[i], 2) + (1 + ksi[i] / beta) * ksi[i] / (gammak[i]+epsilon))) / (2 * (beta + ksi[i]));
                if(ensig[i]<10)
                {
                sum_ensig += pow(ensig[i], 2);
                }
                if(fftmagoutput[i]<10)
                {
                sum_nsig += pow(fftmagoutput[i], 2);
                }
            }             // printf("%f\n",sum_ensig);
            //printf("%f\n",sum_nsig);
            
            float PR = sum_ensig/sum_nsig;
           // printf("%f\n",PR);

            
            //Musical noise reduction
            if (PR >= 0.4)
                PRT = 1;
            else
                PRT = PR;
            
            if (PRT == 1)
                N = 1;
            else
                N = 2 * round((1 - PRT / 0.4) *2) + 1;
            
            //printf("%f\n",N);
            for (int i = 0; i < (int) N; i++)
                H[i] = 1 / N;
            //	H(1:N) = 1 / N;
            
            for (int i = 0; i < N + nFFT - 1; i++)
            {
                int kmin, kmax, k;
                
                HPF[i] = 0;
                
                kmin = (i >= nFFT - 1) ? i - (nFFT - 1) : 0;
                kmax = (i < N - 1) ? i : N - 1;
                
                for (k = kmin; k <= kmax; k++)
                    HPF[i] += H[k] * sqrt(hw[i - k]* hw[i - k]);
            }
            
                for (int i = 0; i < nFFT; i++)
                {
                    fftmagoutput[i] = fftmagoutput[i] * hw[i];
                    
                    X->real[i]=X->real[i]*hw[i];
                    X->imaginary[i]=X->imaginary[i]*hw[i];
                    ensig[i]=fftmagoutput[i];
                  //  printf("%f\n",ensig[i]);

                    //self->magnitudeRight[i] = fftmagoutput[i];
                    if (fftmagoutput[i]<100)
                    {
                        // total_speechpower+=magnitudeLeft[i]*magnitudeLeft[i];
                        total_speechpower+=pow(fftmagoutput[i],2);
                    }
                    if(noise_pow[i]<100)
                    {
                        total_noisepower+=noise_pow[i];
                    }
                
             //  }
           // for (int i = 0; i < nFFT; i++)
          // {
                Xk_prev[i] = pow(fftmagoutput[i],2);
                }
        }
        sum_SNR+=SNR_db;
        snr_counter++;
        if (snr_counter==100)
        {
            //pthread_mutex_lock(&mutex);
            snr_avg=sum_SNR/snr_counter;
            //  __android_log_print(ANDROID_LOG_VERBOSE, "MyApp", "The value of SNR_db is %f",snr_counter );
            sum_SNR=0;
            snr_counter=0;
        }
        
        //converting back to time domain
        Y->invTransform(Y,X->real,X->imaginary);
        
        
        
        for(int i=0;i<FrameSize;i++)
        {
            output_final[i]=(output_old[i]+Y->real[i])*sys_win[i];
            output_old[i]=Y->real[i+FrameSize];
        }
        fir(output_final,float_output,FrameSize);
        for (int i = 0; i < FrameSize; i++)
        {

        float_output[i]=float_output[i]*1.2;
        }
    }
        for (int i = 0; i < FrameSize; i++)
        {
        
        output[i] = float_output[i] * FLOAT2SHORT ;
        //output[i]=output[i]*3;
        //printf("%f\n",float_output[i]);
        }
    
    if (tempBuffer.mDataByteSize != sourceBuffer.mDataByteSize)
    {
        free(tempBuffer.mData);
        tempBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
        tempBuffer.mData = malloc(sourceBuffer.mDataByteSize);
    }
    memcpy(tempBuffer.mData, output, bufferList->mBuffers[0].mDataByteSize);
}

- (IBAction)SwitchPressed:(id)sender
{
    if(EnhancedSwitch.on)
    {
        on=1;
    }
    else
    {
        on=0;
    }
}

- (IBAction)betaValue:(id)sender {
    [self updateBeta];
}

- (IBAction)buttonPressed:(id)sender {
     [self updateFormants];
}

- (IBAction)beta1Value:(id)sender {
    [self updateBeta];
}

@end
