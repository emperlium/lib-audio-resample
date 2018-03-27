use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::Resample',
    VERSION_FROM        => 'lib/Nick/Audio/Resample.pm',
    AUTHOR              => 'Nick Peskett',
    LIBS                => [ '-lsamplerate' ],
    DEFINE              => '-DINCLUDE_SAMPLERATE_H',
    TEST_REQUIRES       => {
        'Test::More' => 0,
        'Digest::MD5' => 0
    }
);
