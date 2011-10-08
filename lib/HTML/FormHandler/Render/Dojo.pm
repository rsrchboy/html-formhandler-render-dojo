package HTML::FormHandler::Render::Dojo;

# ABSTRACT: a HFH render role for Dojo-based forms

use Moose::Role;
use namespace::autoclean -also => '_alias';
use MooseX::AttributeShortcuts;
use HTML::Tiny;
use HTML::Entities;

sub _alias { ($_[0] => "_simple_$_[0]") }

with 'HTML::FormHandler::Render::Simple' => {
        -excludes => [ qw{
            render
            render_field_struct
            render_field
            render_start
            render_end
            render_submit
        } ],
        -alias => {
            render_field => '_simple_render_field',
            render_start => '_simple_render_start',
            _alias('render_submit'),
            _alias('render'),
        },
    };

requires 'dojo_base';
requires 'dojo_version';
requires 'dojo_theme';

has _dojotypes => (
    traits     => ['Hash'],
    is         => 'ro',
    isa        => 'HashRef',
    lazy       => 1,
    builder    => 1,

    handles => {

        dojotype_for     => 'get',
        has_dojotype_for => 'exists',
        set_dojotype_for => 'set',
        dojotypes        => 'values',
    },
);

sub _build__dojotypes {

    return {
        text        => 'dijit.form.TextBox',
        textarea    => 'dijit.form.Textarea',
        select      => 'dijit.form.FilteringSelect',
        checkbox    => 'dijit.form.CheckBox',
        button      => 'dijit.form.Button',
        submit      => 'dijit.form.Button',
        #multiple    => 'dijit.form.MultiSelect',
        multiple    => 'dojox.form.CheckedMultiSelect',
    };
}

has _required_dijits => (

    traits => ['Hash'],
    is     => 'lazy',
    isa    => 'HashRef[Str]',

    handles => {

        required_dijits     => 'keys',
        mark_dijit_required => 'set',
        dijit_is_required   => 'exists',
    },
);

sub _build__required_dijits {

    return { map { $_ => 1 } qw{ dojox.form.Manager dijit.form.Form } };
}

has _required_css => (

    traits => ['Hash'],
    is     => 'lazy',
    isa    => 'HashRef[Str]',

    handles => {

        required_css      => 'keys',
        mark_css_required => 'set',
        css_is_required   => 'exists',
    },
);

my $_tweak = sub {
    my ($orig, $self) = (shift, shift);

    $self->$orig($_ => 1) for @_;
    return;
};

around mark_css_required    => $_tweak;
around mark_dijit_required => $_tweak;

sub _build__required_css { { } }

sub render_script_open  { qq{<script type="text/javascript">\n} }
sub render_script_close { qq{</script>\n\n}                     }

sub render_script_block {
    my ($self) = @_;

    my $output = $self->render_script_open;

    $output .= "dojo.require('$_');\n"
        for $self->required_dijits;

    $output .= $self->render_script_close;

    return $output;
}

sub render_css_open  { qq{<style type="text/css">\n} }
sub render_css_close { qq{</style>\n}                }

sub _module_to_css {
    my ($self, $module) = @_;

    my @parts = split /\./, $module;

    $parts[-1] = "resources/$parts[-1].css";
    $module = join '/', @parts;

    return $module;

    $module =~ s!\.!/!g;
    #$module =~ s!/([^/]*)!
    $module .= '.css';

    return $module;
}

sub render_css_block {
    my $self = shift @_;

    my $dojo_base    = $self->dojo_base;
    my $dojo_version = $self->dojo_version;


    # first, see if any modules look like they need additional css...
    my @css =
        map  { $self->_module_to_css($_) }
        grep { /^dojox/                  }
        $self->required_dijits
        ;

    push @css, $self->required_css;

    return q{} unless @css;

    my $body =
        join "\n",
        map { "    \@import '$dojo_base/$dojo_version/$_';" }
        @css
        ;

    return $self->render_css_open . "$body\n" . $self->render_css_close;
}

sub render_start {
    my ($self) = @_;

    my $output = $self->_simple_render_start;

    $self->mark_dijit_required('dojox.form.Manager');
    $output =~ s/^<form //;
    return $output;
}

sub render {
    my ($self) = @_;

    my $output = $self->_simple_render;

    # these must be done second, to pick up the dependencies generated
    my $css    = $self->render_css_block;
    my $script = $self->render_script_block;

    #return qq{$script <div dojoType="dijit.form.Form" $output};
    return qq{$css\n$script\n\n<div dojoType="dojox.form.Manager" $output};
}

sub render_end {
    my $self = shift;

    my $output;
    $output .= '</fieldset>' if $self->auto_fieldset;
    $output .= "</div>\n";

    return $output;
}

sub render_field {
    my ($self, $field) = @_;

    my $output = $self->_simple_render_field($field);
    my $widget = $field->widget;

    # don't tamper if we either don't have a dojo type for this widget
    # or iff we already have a dojotype
    #warn $field->widget . '/' . $field->multiple . ": $output";
    warn "$widget: $output";
    return $output if $output =~ / dojotype=/i;
    return $output unless $self->has_dojotype_for($widget);


    # multiple is.... weird.
    my $dojotype
        = $widget eq 'select' && $field->multiple
        ? $self->dojotype_for('multiple')
        : $self->dojotype_for($widget)
        ;

    $self->mark_dijit_required($dojotype);

    my $elt = $widget eq 'select'   ? 'select'
            : $widget eq 'textarea' ? 'textarea'
            : $widget eq 'button'   ? 'button'
            : $widget eq 'submit'   ? 'button'
            :                         'input'
            ;

    # I _think_ 'true' is more correct...
    $output =~ s/multiple="multiple"/multiple="true"/
        if $field->widget eq 'select';

    $output =~ s/<$elt /<$elt dojotype="$dojotype" /;

    warn "new output: $output";

    return $output;
}

sub render_submit {
    my ($self, $field) = @_;

    my $output = $self->_simple_render_submit($field);
    $output =~ s/^<input/<button/;
    $output .= $field->value . '</button>';

    return $output;
}

sub wrapper_start {
    my ($self, $field, $rendered_field, $class) = @_;

    # .... uhh?  guys?
}

sub render_field_struct {
    my ($self, $field, $rendered_field, $class) = @_;

    return $field->wrap_field($field, $rendered_field);

    $self->wrapper_start($field, $rendered_field, $class)
        unless $self->wrapper_dijit eq 'none';


    my $output = qq{\n<div$class>};
    my $l_type =
        defined $self->get_label_type( $field->dijit ) ?
        $self->get_label_type( $field->dijit ) :
        '';
    if ( $l_type eq 'label' && $field->label ) {
        $output .= $self->_label($field);
    }
    elsif ( $l_type eq 'legend' ) {
        $output .= '<fieldset class="' . $field->html_name . '">';
        $output .= '<legend>' . encode_entities($field->label) . '</legend>';
    }
    $output .= $rendered_field;
    foreach my $error ($field->all_errors){
        $output .= qq{\n<span class="error_message">} . encode_entities($error) . '</span>';
    }

    if ( $l_type eq 'legend' ) {
        $output .= '</fieldset>';
    }
    $output .= "</div>\n";
    return $output;
}

!!42;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

This is a L<HTML::FormHandler> renderer role, intended for use with the Dojo
toolkit family.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.

Bugs, feature requests and pull requests through GitHub are most welcome; our
page and repo (same URI):

    https://github.com/RsrchBoy/html-formhandler-render-dojo

=head1 SEE ALSO

L<HTML::FormHanlder::Render::Simple>, http://dojotoolkit.org

=cut

