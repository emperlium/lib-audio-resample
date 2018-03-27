# lib-audio-resample

Wrapper for libsamplerate (AKA Secret Rabbit Code).

## Dependencies

You'll need the [libsamplerate library](http://www.mega-nerd.com/SRC/).

On Ubuntu distributions;

    sudo apt install libsamplerate0-dev

## Note

Currently limited to 16 bit audio.

## Installation

    perl Makefile.PL
    make test
    sudo make install

## Example

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

    my $got;
    while ( $flac -> read() ) {
        $resample -> process()
            and $pulse -> play();
    }
    $resample -> process( 1 )
        and $pulse -> play();

## Methods

### new()

Instantiates a new Nick::Audio::Resample object.

Arguments are interpreted as a hash.

There are three mandatory keys.

- rate\_in

    Sample rate of PCM data read from **buffer\_in**.

- rate\_out

    Sample rate of PCM data written to **buffer\_out**.

- channels

    Number of audio channels.

The following are optional.

- buffer\_in

    Scalar that'll be used to read PCM audio from.

- buffer\_out

    Scalar that'll be used to read PCM audio from.

- quality

    Value from 0 to 4, with 0 being the best quality.

    You can import the **%SR\_QUALITY** hash which has the aliases **BEST**, **MEDIUM**, **FASTEST**, **ZERO\_ORDER\_HOLD** and **LINEAR**.

    default: **0**

### process()

Raeds PCM audio from **buffer\_in** and possibly writes resampled audio to **buffer\_out**, returning number of bytes of PCM written to buffer\_out.

If the optional argument is 1, any buffers will be flushed.

### get\_buffer\_in\_ref()

Returns the scalar currently being used to read PCM audio from.

### get\_buffer\_out\_ref()

Returns the scalar currently being used to write PCM audio to.
