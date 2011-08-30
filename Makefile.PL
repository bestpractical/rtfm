use inc::Module::Install;
RTx('RT-FM');
name('RTFM');
license('GPL version 2');
perl_version('5.008003');

requires_rt('3.4.2');
if (Module::Install::RTx::cmp_version("4.0.0", $RT::VERSION) <= 0) {
    die "\nRTFM has been integrated into core RT in version 4.0 and above; there is no need to install this extension.\n";
}

#version_from('lib/RT/FM.pm');
all_from('lib/RT/FM.pm');

requires(
    'Text::WikiFormat'  => 0,
    'Tree::Simple'      => 0,
    'HTML::TreeBuilder' => 0,
    'Time::ParseDate'   => 0,
    'HTML::FormatText'  => 0,
);
auto_install();

WriteAll();
