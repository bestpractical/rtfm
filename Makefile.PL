use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
license('GPL version 2');
perl_version('5.008003');
#version_from('lib/RT/FM.pm');
all_from('lib/RT/FM.pm');
requires(
    'Text::WikiFormat'  => 0,
    'Tree::Simple'      => 0,
    'HTML::TreeBuilder' => 0,
    'Time::ParseDate'   => 0,
    'HTML::FormatText'  => 0,
);
requires_rt('3.4.2');
{
    my @v = split /\./, "$RT::VERSION";
    if ($v[0] >= 4) {
        die "\n\nRTFM does not work with RT 4 (you have $RT::VERSION).
RTFM has been included in RT 4 as Articles.  
See RT's documentation for upgrading from RTFM to Articles or using the Articles functionality.\n";
    }
}
auto_install();

WriteAll();
