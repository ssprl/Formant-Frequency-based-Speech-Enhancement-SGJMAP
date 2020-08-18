%
%  Implements the main program to involke Formant frequency based SGJMAP function.
% 
%  Usage: Edit the path for input audio file (infile)
%           
%         infile - noisy speech file in .wav format
%         outputFile - enhanced output file in .wav format
%
%  Authors: Gautam Shreedhar Bhat
%
%  Copyright (c) 2018 by Gautam Shreedhar Bhat
%------------------------------------------------------------------------------------

%Input Arguments
%Change the Path to Input
infile = 'C:\GitHub\Formant-Frequency-based-Speech-Enhancement-SGJMAP\Sample\audio_in.wav';
%Change the Path for Output
outputFile = 'C:\GitHub\Formant-Frequency-based-Speech-Enhancement-SGJMAP\Sample\audio_out.wav';

% Read input audio file
[sig_in, Fs] = audioread(infile);

% Invoke Formant based SGJmap function
sig_enh = FormantSGJmap(sig_in, Fs);

% Audiowrite output file 
audiowrite(outputFile,sig_enh,Fs);