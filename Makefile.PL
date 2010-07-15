use inc::Module::Install;

name 'Catalyst-View-Xslate';
all_from 'lib/Catalyst/View/Xslate.pm';

requires 'Catalyst' => 5.80;
requires 'Text::Xslate' => '0.1045';

WriteAll;