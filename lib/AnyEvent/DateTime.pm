use strict;
use warnings;
package AnyEvent::DateTime;
BEGIN {
  $AnyEvent::DateTime::VERSION = '1.120710';
}

# ABSTRACT: Perl module to create AnyEvent timers from DateTime Events

use Class::Load qw/try_load_class/;
use AnyEvent;
use Scalar::Util qw/weaken/;
use Carp qw/croak carp/;

sub new {
  my $pkg = shift;
  my $self = bless { }, $pkg;

  my (%p) = @_;
  $self->{_callback} = $p{callback};
  my $type = $p{type};
  my $method = $p{method}||'new';
  my @args = @{$p{arguments}||[]};
  my $module = 'DateTime::Event::'.$type;
  my ($res, $error) = try_load_class($module);
  unless ($res) { croak "Invalid timer, $module not available: $error\n"; }
  $self->{_set} = $module->$method(@args);
  $self->_set();
  $self
}

sub DESTROY {
  shift->cancel
}

sub cancel {
  my $self = shift;
  delete $self->{_watcher};
}

sub next {
  shift->{_next}
}

sub _set {
  my ($self) = shift;
  my $now = AnyEvent->now;
  my $next = $self->{_next} =
    $self->{_set}->next(DateTime->from_epoch(epoch => $now));
  my $sleep = $self->{_next}->epoch - $now;
  weaken $self;
  $self->{_watcher} =
    AnyEvent->timer(after => $sleep,
                    cb => sub {
                      delete $self->{_watcher};
                      my $res = $self->{_callback}->();
                      if ($res) {
                        $self->_set;
                      }
                    });
}

1;

__END__
=pod

=head1 NAME

AnyEvent::DateTime - Perl module to create AnyEvent timers from DateTime Events

=head1 VERSION

version 1.120710

=head1 AUTHOR

Mark Hindess <soft-cpan@temporalanomaly.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Mark Hindess.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

