package Catalyst::View::Xslate;
use Moose;
use namespace::autoclean;
use Text::Xslate;

our $VERSION = '0.00007';

extends 'Catalyst::View';

has catalyst_var => (
    is => 'rw',
    isa => 'Str',
    default => 'c'
);

has template_extension => (
    is => 'rw',
    isa => 'Str',
    default => '.tx'
);

my $clearer = sub { $_[0]->clear_xslate };

has path => (
    is => 'rw',
    isa => 'ArrayRef',
    trigger => $clearer,
);

has cache_dir => (
    is => 'rw',
    isa => 'Str',
    trigger => $clearer,
);

has cache => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    trigger => $clearer,
);

has function => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} },
    trigger => $clearer,
);

has module => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { +[] },
    trigger => $clearer,
);

has input_layer => (
    is => 'rw',
    isa => 'Str',
    trigger => $clearer,
);
    
has syntax => (
    is => 'rw',
    isa => 'Str',
    trigger => $clearer,
);
    
has escape => (
    is => 'rw',
    isa => 'Str',
    trigger => $clearer,
);
    
has verbose => (
    is => 'rw',
    isa => 'Bool',
    trigger => $clearer,
);

has xslate => (
    is => 'rw',
    isa => 'Text::Xslate',
    clearer => 'clear_xslate',
);

sub _build_xslate {
    my ($self, $c) = @_;

    my $name = $c;
    $name =~ s/::/_/g;

    my %args = (
        path      => $self->path || [ $c->path_to('root') ],
        cache_dir => $self->cache_dir || File::Spec->catdir(File::Spec->tmpdir, $name),
        cache     => $self->cache,
        function  => $self->function,
        module    => $self->module,
    );

    if (my $input_layer = $self->input_layer) {
        $args{input_layer} = $input_layer;
    }

    if (my $syntax = $self->syntax) {
        $args{syntax} = $syntax;
    }

    if (my $escape = $self->escape) {
        $args{escape} = $escape;
    }

    if (my $verbose = $self->verbose) {
        $args{verbose} = $verbose;
    }
    
    my $xslate = Text::Xslate->new(%args);
    $self->xslate( $xslate );
}

sub ACCEPT_CONTEXT {
    my ($self, $c) = @_;
    if ( ! $self->xslate ) {
        $self->_build_xslate( $c );
    }
    return $self;
}

sub process {
    my ($self, $c) = @_;

    my $stash = $c->stash;
    my $template = $stash->{template} || $c->action . $self->template_extension;

    if (! defined $template) {
        $c->log->debug('No template specified for rendering') if $c->debug;
        return 0;
    }

    my $output = eval {
        $self->render( $c, $template, $stash );
    };
    if (my $err = $@) {
        return $self->_rendering_error($c, $err);
    }

    my $res = $c->response;
    if (! $res->content_type) {
        $res->content_type('text/html; charset=utf-8');
    }

    $res->body( $output );

    return 1;
}

sub render {
    my ($self, $c, $template, $vars) = @_;

    if ( ! $self->xslate ) {
        $self->_build_xslate( $c );
    }

    local $vars->{ $self->catalyst_var } =
        $vars->{ $self->catalyst_var } || $c;

    return $self->xslate->render( $template, $vars );
}

sub _rendering_error {
    my ($self, $c, $err) = @_;
    my $error = qq/Couldn't render template "$err"/;
    $c->log->error($error);
    $c->error($error);
    return 0;
}


__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Catalyst::View::Xslate - Text::Xslate View Class

=head1 SYNOPSIS

    package MyApp::View::Xslate;
    use strict;
    use base qw(Catalyst::View::Xslate);

    1;

=head1 VIEW CONFIGURATION

You may specify the following configuration items in from your config file
or directly on the view object.

=head2 catalyst_var

The name used to refer to the Catalyst app object in the template

=head2 template_extension

The suffix used to auto generate the template name from the action name
(when you do not explicitly specify the template filename);

=head2 Text::Xslate CONFIGURATION

The following parameters are passed to the Text::Xslate constructor.
When reset during the life cyle of the Catalyst app, these parameters will
cause the previously created underlying Text::Xslate object to be cleared

=head2 path

=head2 cache_dir

=head2 cache

=head2 function

=head2 module

Use this to enable TT2 compatible variable methods via Text::Xslate::Bridge::TT2 or Text::Xslate::Bridge::TT2Like

    package MyApp::View::Xslate;
    use Moose;
    extends 'Catalyst::View::Xslate';

    has '+module' => (
        default => sub { [ 'Text::Xslate::Bridge::TT2Like' ] }
    );

=head1 TODO

Currently there is no way to render a string.

=head1 AUTHOR

Copyright (c) 2010 Daisuke Maki C<< <daisuke@endeworks.jp> >>

=head1 LICENSE 

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
