package Catalyst::View::Xslate;
use Moose;
use Moose::Util::TypeConstraints qw(coerce from where via subtype);
use Encode;
use Text::Xslate;
use namespace::autoclean;
use Scalar::Util qw/blessed weaken/;

our $VERSION = '0.00010';

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

has content_charset => (
    is => 'rw',
    isa => 'Str',
    default => 'UTF-8'
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
    isa => 'Int',
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

my $expose_methods_tc = subtype 'HashRef', where { $_ };
coerce $expose_methods_tc,
  from 'ArrayRef',
  via {
    my %values = map { $_ => $_ } @$_;
    return \%values;
  };

has expose_methods => (
    is => 'ro',
    isa => $expose_methods_tc,
    predicate => 'has_expose_methods',
    coerce => 1,
);

sub _build_xslate {
    my ($self, $c) = @_;

    my $name = $c;
    $name =~ s/::/_/g;

    my $function = $self->function;
    if ($self->has_expose_methods) {
        my $meta = $self->meta;
        my @names = keys %{$self->expose_methods};
        foreach my $method_name (@names) {
            my $method = $meta->find_method_by_name( $self->expose_methods->{$method_name} );
            unless ($method) {
                Catalyst::Exception->throw( "$method_name not found in Xslate view" );
            }
            my $method_body = $method->body;
            my $weak_ctx = $c;
            weaken $weak_ctx;

            my $sub = sub {
                $self->$method_body($weak_ctx, @_);
            };

            $function->{$method_name} = $function->{$method_name}
              ? Catalyst::Exception->throw("$method_name can't be a method in the View and defined as a function.")
              : $sub;
        }
    }

    my %args = (
        path      => $self->path || [ $c->path_to('root') ],
        cache_dir => $self->cache_dir || File::Spec->catdir(File::Spec->tmpdir, $name),
        cache     => $self->cache,
        function  => $function,
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
        $res->content_type('text/html; charset=' . $self->content_charset);
    }

    $res->body( encode($self->content_charset, $output) );

    return 1;
}

sub render {
    my ($self, $c, $template, $vars) = @_;

    $vars = $vars ? $vars : $c->stash;

    if ( ! $self->xslate ) {
        $self->_build_xslate( $c );
    }

    local $vars->{ $self->catalyst_var } =
        $vars->{ $self->catalyst_var } || $c;
    
    if(ref $template eq 'SCALAR') {
        return $self->xslate->render_string( $$template, $vars );
    } else {
        return $self->xslate->render($template, $vars );
    }
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
    use Moose;
    extends 'Catalyst::View::Xslate';

    1;

=head1 VIEW CONFIGURATION

You may specify the following configuration items in from your config file
or directly on the view object.

=head2 catalyst_var

The name used to refer to the Catalyst app object in the template

=head2 template_extension

The suffix used to auto generate the template name from the action name
(when you do not explicitly specify the template filename);

=head2 content_charset

The charset used to output the response body. The value defaults to 'UTF-8'.

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

=head2 expose_methods

Use this option to specify methods from the View object to be exposed in the
template. For example, if you have the following View:

    package MyApp::View::Xslate;
    use Moose;
    extends 'Catalyst::View::Xslate';

    sub foo {
        my ( $self, $c, @args ) = @_;
        return ...; # do something with $self, $c, @args
    }

then by setting expose_methods, you will be able to use foo() as a function in
the template:

    <: foo("a", "b", "c") # calls $view->foo( $c, "a", "b", "c" ) :>

C<expose_methods> takes either a list of method names to expose, or a hash reference, in order to alias it differently in the template.

    MyApp::View::Xslate->new(
        # exposes foo(), bar(), baz() in the template
        expose_methods => [ qw(foo bar baz) ]
    );

    MyApp::View::Xslate->new(
        # exposes foo_alias(), bar_alias(), baz_alias() in the template,
        # but they will in turn call foo(), bar(), baz(), on the view object.
        expose_methods => {
            foo => "foo_alias",
            bar => "bar_alias",
            baz => "baz_alias",
        }
    );

=head1 METHODS

=head1 C<$view->process($c)>

Called by Catalyst.

=head2 C<$view->render($c, $template, \%vars)>

Renders the given C<$template> using variables \%vars.

C<$template> can be a template file name, or a scalar reference to a template
string.

    $view->render($c, "/path/to/a/template.tx", \%vars );

    $view->render($c, \'This is a xslate template!', \%vars );

=head1 AUTHOR

Copyright (c) 2010 Daisuke Maki C<< <daisuke@endeworks.jp> >>

=head1 LICENSE 

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
