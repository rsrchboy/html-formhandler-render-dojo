package HTML::FormHandler::Render::Dojo::CDN::AOL;

# ABSTRACT: Use Google's CDN for dojo resources

use Moose::Role;
use namespace::autoclean;

with 'HTML::FormHandler::Render::Dojo';

# AFAIK only http is supported (https caused invalid cert complaints)
sub dojo_base { 'http://o.aolcdn.com/dojo' }

!!42;
