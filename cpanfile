requires 'Catalyst', '5.8';
requires 'File::Find';
requires 'Scalar::Util';
requires 'Text::Xslate', '0.1045';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
};
