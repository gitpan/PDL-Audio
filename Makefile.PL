require 5.005; # lower versions of perl not supported

use ExtUtils::MakeMaker;

use PDL::Core::Dev;

system "cd sndlib && ./configure";

@pack = ["audio.pd",Audio,PDL::Audio];
%hash = pdlpp_stdargs(@pack);

$hash{depend}{'Audio.o'} = 'xlib.h remez.h';
$hash{depend}{'xlib.o'} = 'xlib.h remez.h';
$hash{OBJECT} = "Audio.o xlib.o remez.o";

do "./config.pl";

$hash{PM}{'Scales.pm'} = '$(INST_LIBDIR)/Audio/Scales.pm';
$hash{PM}{'Pitches.pm'} = '$(INST_LIBDIR)/Audio/Pitches.pm';
                       
push @{$hash{DIR}}, "sndlib";

WriteMakefile(%hash,
      MYEXTLIB	=> "sndlib/sndlib.a",
      VERSION_FROM => 'audio.pd',
      DIR	=> [],
      XS	=> {
                     "Audio.xs" => "Audio.c",
                   },
);

sub MY::postamble {
   my $self=shift;
   pdlpp_postamble(@pack)."

.EXPORT_ALL_VARIABLES:

force:

\$(MYEXTLIB): force
	cd sndlib && \$(MAKE)

";
}
