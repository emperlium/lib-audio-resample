#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <samplerate.h>

#define PCM_MAX_VALUE (1.0 * 0x8000)
#define IN_BUFFER_SIZE 16384
#define OUT_BUFFER_SIZE 16384

struct nickaudioresample {
    SRC_DATA src_data;
    SRC_STATE *src_state;
    uint channels;
    float buffer_in [IN_BUFFER_SIZE];
    float buffer_out [OUT_BUFFER_SIZE];
    uint buffer_pos;
    char *pcm_out;
    SV *scalar_in;
    SV *scalar_out;
};

typedef struct nickaudioresample NICKAUDIORESAMPLE;

MODULE = Nick::Audio::Resample  PACKAGE = Nick::Audio::Resample

static NICKAUDIORESAMPLE *
NICKAUDIORESAMPLE::new_xs( rate_in, rate_out, channels, converter, scalar_in, scalar_out )
        U32 rate_in;
        U32 rate_out;
        U8 channels;
        U8 converter;
        SV *scalar_in;
        SV *scalar_out;
    CODE:
        if ( src_get_name( converter ) == NULL ) {
            croak( "Bad converter number." );
        }
        Newxz( RETVAL, 1, NICKAUDIORESAMPLE );
        int error;
        if (
            ( RETVAL -> src_state
                = src_new( converter, channels, &error )
            ) == NULL
        ) {
            croak(
                "Converter init failed: %04s",
                src_strerror( error )
            );
        }
        RETVAL -> buffer_pos = 0;
        RETVAL -> channels = channels;
        RETVAL -> src_data.end_of_input = 0;
        RETVAL -> src_data.input_frames = 0;
        RETVAL -> src_data.src_ratio = ( double )(
            ( double )rate_out / ( double )rate_in
        );
        RETVAL -> src_data.output_frames = OUT_BUFFER_SIZE;
        Newx(
            RETVAL -> pcm_out,
            (int)(
                IN_BUFFER_SIZE * 2 * RETVAL -> src_data.src_ratio
            ) + 1,
            char
        );
        RETVAL -> scalar_in = SvREFCNT_inc(
            SvROK( scalar_in )
            ? SvRV( scalar_in )
            : scalar_in
        );
        RETVAL -> scalar_out = SvREFCNT_inc(
            SvROK( scalar_out )
            ? SvRV( scalar_out )
            : scalar_out
        );
        if (
            src_is_valid_ratio( RETVAL -> src_data.src_ratio ) == 0
        ) {
            croak(
                "Sample rate ratio out of valid range (%04f)",
                RETVAL -> src_data.src_ratio
            );
        }
    OUTPUT:
        RETVAL

void
NICKAUDIORESAMPLE::DESTROY()
    CODE:
        SvREFCNT_dec( THIS -> scalar_in );
        SvREFCNT_dec( THIS -> scalar_out );
        Safefree( THIS -> pcm_out );
        Safefree( THIS );

SV *
NICKAUDIORESAMPLE::get_buffer_in_ref()
    CODE:
        RETVAL = newRV_inc( THIS -> scalar_in );
    OUTPUT:
        RETVAL

SV *
NICKAUDIORESAMPLE::get_buffer_out_ref()
    CODE:
        RETVAL = newRV_inc( THIS -> scalar_out );
    OUTPUT:
        RETVAL

U32
NICKAUDIORESAMPLE::process( flush = false )
    bool flush;
    CODE:
        THIS -> src_data.end_of_input = flush ? 1 : 0;
        int len_out = THIS -> buffer_pos;
        if (
            SvOK( THIS -> scalar_in )
        ) {
            STRLEN len_in;
            unsigned char *u_pcm_in = SvPV( THIS -> scalar_in, len_in );
            signed char *s_pcm_in = u_pcm_in + 1;
            len_in /= 2;
            if (
                len_out + len_in > IN_BUFFER_SIZE
            ) {
                croak(
                    "Too much data (%d) for maximum buffer size (%d)",
                    len_out + len_in,
                    IN_BUFFER_SIZE
                );
            }
            float *buff_in = THIS -> buffer_in + len_out;
            len_out += len_in;
            while ( len_in-- ) {
                buff_in[0] = ( float )(
                    (
                        ( s_pcm_in[0] << 8 ) | u_pcm_in[0]
                    ) / PCM_MAX_VALUE
                );
                buff_in ++;
                s_pcm_in += 2;
                u_pcm_in += 2;
            }
        } else {
            flush = true;
        }
        THIS -> src_data.input_frames = len_out / THIS -> channels;
        THIS -> src_data.data_in = THIS -> buffer_in;
        THIS -> src_data.data_out = THIS -> buffer_out;
        int error, to_read, sample;
        char *pcm_out = THIS -> pcm_out;
        float *buff_out;
        while ( 1 ) {
            if ((
                error = src_process(
                    THIS -> src_state,
                    &( THIS -> src_data )
                )
            )) {
                croak(
                    "Converter error: %04s",
                    src_strerror( error )
                );
            }
            if ( THIS -> src_data.output_frames_gen == 0 ) {
                break;
            }
            THIS -> src_data.data_in += THIS -> src_data.input_frames_used * THIS -> channels;
            THIS -> src_data.input_frames -= THIS -> src_data.input_frames_used;
            to_read = THIS -> src_data.output_frames_gen * THIS -> channels;
            buff_out = THIS -> buffer_out;
            while ( to_read-- ) {
                sample = (int)( buff_out[0] * PCM_MAX_VALUE );
                buff_out++;
                if (
                    sample > PCM_MAX_VALUE
                ) {
                    sample = PCM_MAX_VALUE - 1;
                } else if (
                    sample < -PCM_MAX_VALUE
                ) {
                    sample = -PCM_MAX_VALUE + 1;
                }
                pcm_out[0] = sample & 0xff;
                pcm_out[1] = ( sample >> 8 ) & 0xff;
                pcm_out += 2;
            }
        }
        THIS -> buffer_pos = (
            THIS -> src_data.input_frames > 0
            ? THIS -> src_data.input_frames
            : 0
        );
        RETVAL = pcm_out - THIS -> pcm_out;
        sv_setpvn( THIS -> scalar_out, THIS -> pcm_out, RETVAL );
    OUTPUT:
        RETVAL
