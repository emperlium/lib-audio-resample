package Nick::Audio::Resample;

use strict;
use warnings;

use XSLoader;
use Carp;

use base 'Exporter';

our( $VERSION, @EXPORT_OK, %SR_QUALITY );

BEGIN {
    $VERSION = '0.01';
    @EXPORT_OK = qw( %SR_QUALITY );
    %SR_QUALITY = qw(
        BEST            0
        MEDIUM          1
        FASTEST         2
        ZERO_ORDER_HOLD 3
        LINEAR          4
    );
    XSLoader::load 'Nick::Audio::Resample' => $VERSION;
}

=pod

=head1 NAME

Nick::Audio::Resample - Wrapper for libsamplerate (AKA Secret Rabbit Code).

=head1 SYNOPSIS

    use Nick::Audio::Resample '%SR_QUALITY';
    use Nick::Audio::FLAC;
    use Nick::Audio::PulseAudio;

    my $sample_rate_out = 48000;

    my( $buff_in, $buff_out );
    my $flac = Nick::Audio::FLAC -> new(
        'test.flac',
        'buffer_out' => \$buff_in
    );

    my $resample = Nick::Audio::Resample -> new(
        'rate_in'       => $flac -> get_sample_rate(),
        'rate_out'      => $sample_rate_out,
        'channels'      => $flac -> get_channels(),
        'buffer_in'     => \$buff_in,
        'buffer_out'    => \$buff_out,
        'quality'       => $SR_QUALITY{'MEDIUM'}
    );

    my $pulse = Nick::Audio::PulseAudio -> new(
        'sample_rate'   => $sample_rate_out,
        'channels'      => $flac -> get_channels(),
        'buffer_in'     => \$buff_out
    );

    while ( $flac -> read() ) {
        $resample -> process()
            and $pulse -> play();
    }
    $resample -> process( 1 )
        and $pulse -> play();

=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::Resample object.

Arguments are interpreted as a hash.

There are three mandatory keys.

=over 2

=item rate_in

Sample rate of PCM data read from B<buffer_in>.

=item rate_out

Sample rate of PCM data written to B<buffer_out>.

=item channels

Number of audio channels.

=back

The following are optional.

=over 2

=item buffer_in

Scalar that'll be used to read PCM audio from.

=item buffer_out

Scalar that'll be used to read PCM audio from.

=item quality

Value from 0 to 4, with 0 being the best quality.

You can import the B<%SR_QUALITY> hash which has the aliases B<BEST>, B<MEDIUM>, B<FASTEST>, B<ZERO_ORDER_HOLD> and B<LINEAR>.

default: B<0>

=back

=head2 process()

Raeds PCM audio from B<buffer_in> and possibly writes resampled audio to B<buffer_out>, returning number of bytes of PCM written to buffer_out.

If the optional argument is 1, any buffers will be flushed.


=head2 get_buffer_in_ref()

Returns the scalar currently being used to read PCM audio from.

=head2 get_buffer_out_ref()

Returns the scalar currently being used to write PCM audio to.

=cut

sub new {
    my( $class, %settings ) = @_;
    my @missing;
    @missing = grep(
        ! exists $settings{$_},
        qw( rate_in rate_out channels )
    ) and croak(
        'Missing parameters: ' . join ', ', @missing
    );
    exists( $settings{'quality'} )
        or $settings{'quality'} = $SR_QUALITY{'BEST'};
    for ( qw( in out ) ) {
        exists( $settings{ 'buffer_' . $_ } )
            or $settings{ 'buffer_' . $_ } = do{ my $x = '' };
    }
    return Nick::Audio::Resample -> new_xs(
        @settings{ qw(
            rate_in rate_out channels quality
            buffer_in buffer_out
        ) }
    );
}

1;
