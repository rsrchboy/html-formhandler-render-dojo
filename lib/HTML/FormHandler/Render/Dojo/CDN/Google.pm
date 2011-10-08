package HTML::FormHandler::Render::Dojo::CDN::Google;

# ABSTRACT: Use Google's CDN for dojo resources

use Moose::Role;
use namespace::autoclean;

with 'HTML::FormHandler::Render::Dojo';

sub dojo_base    { '//ajax.googleapis.com/ajax/libs/dojo' }

!!42;
