use strict;
use warnings;

use Test::More tests => 3;

use Digest::MD5 'md5_base64';

use_ok( 'Nick::Audio::Resample' );

our %SR_QUALITY;
Nick::Audio::Resample -> import( '%SR_QUALITY' );

my @want = (
    [  7816, 'NX7sQyU34t8OIAQXiSii1Q' ],
    [  8192, 'uNuVcdnfOgDR4uMo4iHn0w' ],
    [  8192, 'jp/Q+KRqE/w9iSEYjWxFjQ' ],
    [  8192, '9EDQyajNKYZ/dzMfxx61Iw' ],
    [   384, 'xbPgQkPJpH4CWvNFrXsLSQ' ]
);

my( $buff_in, $buff_out );
my $resample = Nick::Audio::Resample -> new(
    'rate_in'       => 22050,
    'rate_out'      => 44100,
    'channels'      => 2,
    'quality'       => $SR_QUALITY{'MEDIUM'},
    'buffer_in'     => \$buff_in,
    'buffer_out'    => \$buff_out
);

ok( defined( $resample ), 'new()' );

my $steps = 2 ** 12;
my $step = 65536 / $steps;
my $data = pack 's*', map(
    { $_, $_ * -1 }
    -32767, map(
        $_ * $step,
        ( -$steps / 2 ) + 1
        ..
        ( $steps / 2 ) - 1
    ), 32767
);

my @got;
my $len = length $data;
my $block = 4096;
for (
    my $off = 0;
    $off < $len;
    $off += $block
) {
    $buff_in = substr $data, $off, $block;
    $resample -> process( $off + $block >= $len )
        and push @got => [
            length( $buff_out ),
            md5_base64( $buff_out )
        ];
}

is_deeply( \@got, \@want, 'process()' );
