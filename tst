#!/usr/bin/perl

#use blib;
use PDL;
use PDL::Audio;
#use PDL::Graphics::PGPLOT;
use PDL::Audio::Pitches;
use PDL::Dbg;
use PDL::Complex;

$|=1;
   
*_dur2time = *PDL::Audio::_dur2time;
sub HZ (){ 22050 };

sub freqz {
   my ($a, $b, $w) = @_;
   $w = 512 unless defined $w;
   $w = zeroes($w)->xlinvals(0,M_PI*($w-1)/$w) unless ref $w;
   $w = exp i * r2C $w;
   
   Cabs(Cdiv($a->rCpolynomial($w),$b->rCpolynomial($w)));
}

sub play {
   my $pdl = shift;
   #line $pdl;
   $pdl->scale2short->playaudio(rate => HZ, @_);
}

$pdl = raudio "kongas.wav";

print describe_audio($pdl), "\n";

$pdl = $pdl->float->filter_src($pdl->rate / HZ);
$pdl = $pdl->filter_center;

my @stdenv = (pdl(0,0.1,0.2,0.9,1), pdl(0,1,0.6,0.6,0));
$env = gen_env $pdl, @stdenv;

sub tst($$) {
   push @tests, [$_[0], $_[1]];
}

tst src, sub {
   for (qw(22050 11025 8000)) {
      print " $_"; play $pdl->filter_src(44100 / $_), rate => $_;
   }
};

tst contrast_enhance, sub {
   for (qw(0.1 0.2 0.3 0.6 1)) {
      print " $_"; play $pdl->filter_contrast_enhance($_);
   }
};

tst granulate, sub {
   for (qw(1.5 1.3 1.1 1.0 0.8 0.6 0.5)) {
      print " $_"; play $pdl->filter_granulate($_);
   }
   print " +SRC:";
   for (qw(1.5 1.3 1.1 1.0 0.8 0.6 0.5)) {
      print " $_"; play $pdl->filter_granulate($_)->filter_src($_), rate => 44100;
   }
};

tst modulated_src, sub {
   print " 2 hz 0.7 sine...";
   play $pdl->filter_src(1, 5, 0.7 * gen_oscil $pdl,   2/HZ);
   print " 5 hz 0.3 sine...";
   play $pdl->filter_src(1, 5, 0.3 * gen_oscil $pdl,  20/HZ);
   print " 90 hz 0.5 sine...";
   play $pdl->filter_src(1, 5, 0.5 * gen_oscil $pdl,  90/HZ);
   print " 300 hz 0.8 sine...";
   play $pdl->filter_src(1, 5, 0.8 * gen_oscil $pdl, 300/HZ);
};

tst 'ring_modulate', sub {
   print " ring modulated with 20 hz sine";
   play $pdl->ring_modulate(gen_oscil $pdl, 20 / HZ);
   print " ring modulated with 1000 hz sine";
   play $pdl->ring_modulate(gen_oscil $pdl, 1000 / HZ);
};

tst 'touchtones', sub {
   my @h = ( 697, 697, 697, 770, 770, 770, 852, 852, 852, 941, 941, 941);
   my @v = (1209,1336,1477,1209,1336,1477,1209,1336,1477,1209,1336,1477);
   my $dur = HZ*0.22;
   my $env = gen_env $dur, pdl(0,1,2,9,10), pdl(0,1,0.9,0.9,0);
   my @mix;
   for (0..$#h) {
      my ($h, $v) = ($h[$_], $v[$_]);
      $h = $env * gen_oscil $dur, $h/HZ;
      $v = $env * gen_oscil $dur, $v/HZ;
      push @mix, ($_*$dur, $h, $_*$dur, $v);
   };
   play audiomix @mix;
};

tst noise_fm, sub {
   my $pdl;
   print " 100 hz";
   $pdl = gen_rand 2*HZ, 100/HZ;
   $pdl = gen_oscil $pdl, 880/HZ, 0, $pdl * $pdl->xlinvals(0.001,0.1);
   play $pdl * gen_env $pdl, @stdenv;
   print " 6000 hz";
   $pdl = gen_rand 2*HZ, 6000/HZ;
   $pdl = gen_oscil $pdl, 880/HZ, 0, $pdl * $pdl->xlinvals(0.001,0.1);
   play $pdl * gen_env $pdl, @stdenv;
};

tst simple_fm, sub {
   my $fm = gen_triangle $pdl, 16/HZ;
   $fm *= $fm->xlinvals(0,0.1);
   print " 900 hz sine + vibrato"; play $env * gen_oscil $pdl, 900/HZ, 0, $fm;
   print " 900 hz sine + sound"; play $env * gen_oscil $pdl, 1/HZ, 0, $pdl * 0.08;
};

tst filters, sub {
   print " filter_lir(<0.05s echo>)"; play $pdl->filter_lir(pdl(0),pdl(0.5), pdl(HZ*0.05), pdl(0.5));
   print " ppolar(0.8,220)"; play $pdl->filter_ppolar(0.8,220);
   print " zpolar(0.8,220)"; play $pdl->filter_zpolar(0.8,220);
};

tst 'waveshaping', sub {
   # this is the spectrum of a cello playing as3
   my @i = (1.01, 1.99, 2.99, 4.00, 5.00, 6.00, 6.99, 8.00, 9.00, 9.98,
            10.99, 11.99, 13.00, 14.01, 14.99, 16.02, 17.00, 17.98, 19.00, 20.01,
            21.02, 22.02, 22.22, 22.93, 24.05, 25.04, 25.99, 27.00, 29.03);

   my @a = (.0839, .0414, .1265, .0196, .0377, .0117, .0111, .0151, .0207,
            .0033, .0090, .0039, .0039, .0031, .0038, .0023, .0026, .0069, .0020,
            .0017, .0007, .0006, .0002, .0001, .0003, .0002, .0003, .0003, .0003);

   # add a slight vibrato
   my $tri = gen_triangle 4*HZ, 1.5/HZ;
   my $pdl = gen_from_partials (4*HZ, as3/HZ, \@i, \@a, 0, 16/HZ*$tri);

   play $pdl * gen_env $pdl, @stdenv;
};

0&&tst simple_generators, sub {
   print " 1/f noise"; play $env * gen_rand_1f $pdl;
   print " 900 hz sine"; play $env * gen_oscil $pdl, 900/HZ;
   print " 900 hz triangle"; play $env * gen_triangle $pdl, 900/HZ;
   print " 900 hz asyfm"; play $env * gen_asymmetric_fm $pdl, 900/HZ;
   print " 900 hz sine summation"; play $env * gen_sine_summation $pdl, 900/HZ, 0, 5;
   print " 900 hz sum of cosines"; play $env * gen_sum_of_cosines $pdl, 900/HZ, 0, 5;
};

tst noise_filtering, sub {
   my $pdl = gen_rand 2*HZ, 1;
   $pdl = $pdl->filter_ppolar(0.97, 440/HZ);
   $pdl = $pdl->filter_lir(pdl(0),pdl(0.1), pdl(HZ/440),pdl(0.99));
   play $pdl * gen_env $pdl, @stdenv;
};

tst 'spectrum', sub {
   $pdl = gen_fft_window(100, KAISER, -1.0);
   #line spectrum $pdl, 'db';
   #line spectrum $pdl, db', KAISER;
   #line spectrum $pdl, 'db';
   exit;
} if 0;

tst 'karplus', sub {
   my $pdl = concat gen_rand(0.4*HZ, 1), zeroes(5.0*HZ);

   my $dur = 2*HZ;
   my $freq = 440/HZ;
   my $damping = -0.5/HZ;

   $freq *= M_2PI;

   my $e = exp $damping;
   my $c1 = 2 * $e * cos $freq;
   my $c2 = $e * $e;
   my $tm = atan2 ($freq, $damping) / $freq;
   my $scale = sqrt ($damping*$damping + $freq*$freq) * exp (-$damping*$tm) * HZ / 750000;
   print "$scale, $c1, $c2\n";
   $pdl = $pdl->filter_lir(pdl(1), pdl($scale),
                           pdl(1, 2, int(1/$freq+6)), pdl(-$c1, $c2, -$scale*0.1));
   line $pdl;
   play $pdl * gen_env $pdl, @stdenv;

} if 0;

tst 'karplus2', sub {
   my $pdl = concat gen_rand(1.*HZ, 1), zeroes(5.0*HZ);

   my $dur = 2*HZ;
   my $freq = 440/HZ;
   my $freq2 = 88/HZ;
   my $reson = 0.05;

   $pdl = $pdl->filter_lir(
                           pdl(1, 2, 1,2),
                           pdl(-$reson*$reson, 2*$reson*cos(M_2PI*$freq),
                               -$reson*$reson, 2*$reson*cos(M_2PI*$freq2)),
                           pdl(int(1/$freq),int(1/$freq2)), pdl(0.49, 0.499));
   line $pdl;
   play $pdl; # * gen_env $pdl, @stdenv;
} if 0;

tst 'vibro', sub {
   my $pdl;
   $pdl = gen_oscil 2*HZ, 40/HZ;
   #$pdl = gen_oscil 2*HZ, 40/HZ, 0, $pdl->xlinvals(0,80/HZ);
   #$pdl = $pdl->filter_zpolar(0.9, 80/HZ);
   #line $pdl->slice("0:30000");
   $pdl = pdl(1,1)->partials2polynomial(1)->polynomial($pdl);
   line $pdl;
   play $pdl;
   exit;
} if 0;

tst chorus, sub {
   play $pdl;
   my $lfo = $osc = 0.02 * gen_rand $pdl, 30/HZ;
   my $dly = $pdl->filter_src(1, undef,  $lfo);
   play $dly->rshift(0.030*HZ) + $pdl;
};

tst phazor, sub {
   play $pdl;
   print "rfft...";
   my $fft = rfft($pdl)->Cr2p;
   my $im = im $fft; $im .= $im->rshift(-10000);
   print "irfft...";
   my $fft = irfft($fft->Cp2r);
   play $fft;
} if 0;

tst strong, sub {
   # as done originally by Alex Strong
   my $pdl = zeroes HZ*5;
   my $freq = int (HZ/220);
   my $x = $pdl->slice("0:".($freq-1)); $x .= gen_rand $x, 1;

   $pdl = $pdl->filter_lir(pdl(0),pdl(1),pdl($freq,$freq+1),pdl(0.5,0.5));
   play $pdl;
};

#print "original version..."; play $pdl; print "\n";

for (reverse @tests) {
   my ($name, $sub) = @$_;
   print "$name...";
   &$sub;
   print "\n";
}

exit;

#$pdl2 = filter_granulate $pdl, 0.8, rate => 44100;
$pdl2 = filter_contrast_enhance $pdl, 0.1;
#$pdl->scale2short->playaudio(rate => 44100);
$pdl2->scale2short->playaudio(rate => 44100);
exit;

$pdl = zeroes(4096);
$pdl = sin $pdl->xlinvals(0,20) + sin $pdl->xlinvals(0,50);
$pz  = zeroes(40960);
$pdl2 = filter_src ($pdl, 0.5, 80, $pz);
#line $pdl2;
$pdl2->scale2short->playaudio;




