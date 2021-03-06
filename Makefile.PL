use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
license('GPL version 2');
perl_version('5.008003');
#version_from('lib/RT/FM.pm');
all_from('lib/RT/FM.pm');
requires_rt('3.4.2');
requires(
    'Text::WikiFormat'  => 0,
    'Tree::Simple'      => 0,
    'HTML::TreeBuilder' => 0,
    'Time::ParseDate'   => 0,
    'HTML::FormatText'  => 0,
);
auto_install();


# XXX: This should be reported by M::I::RTx
my ($lib_path) = $INC{'RT.pm'} =~ /^(.*)[\\\/]/;
my $local_lib_path = "$RT::LocalPath/lib";

substitute( {
        RT_LIB_PATH => join( ' ', $local_lib_path, $lib_path ),
    },
    {
        sufix => '.in',
    },
    't/lib/RT/FM/Test.pm',
);


WriteAll();
