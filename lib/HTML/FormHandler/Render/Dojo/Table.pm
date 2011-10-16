package HTML::FormHandler::Render::Dojo::Table;

use Moose::Role;
use namespace::autoclean;

my $_table_as = sub { $_[0] => "_table_$_[0]" };
my $_dojo_as  = sub { $_[0] => "_dojo_$_[0]"  };

my @METHODS = qw( render_end render_start render_field_struct );

with
    'HTML::FormHandler::Render::Dojo' => {
        -excludes => [ @METHODS, q{ } ],
        -alias    => { map { $_dojo_as->($_) } @METHODS },
    },
    'HTML::FormHandler::Render::Table' => {
        -excludes => [ @METHODS, qw{ render_form_errors render render_field render_submit html_form_tag } ],
        -alias    => { map { $_table_as->($_) } @METHODS },
    },
    ;

sub render_field_struct { shift->_table_render_field_struct(@_) }
sub render_start        { shift->_table_render_start(@_)        }

sub render_end {
    my $self = shift @_;

    return $self->_table_render_end(@_) . $self->_dojo_render_end(@_);
}


!!42;

__END__

package TestClass;

use Moose;
with 'HTML::FormHandler::Render::Dojo::Table';

!!42;

__END__
