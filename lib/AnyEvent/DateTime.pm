use strict;
use warnings;
package AnyEvent::DateTime;

# ABSTRACT: Perl module to create AnyEvent timers from DateTime Events

=head1 SYNOPSIS

  use AnyEvent::DateTime;
  my $t = AnyEvent::DateTime->new(type => 'Recurrence',
                                  method => 'hourly',
                                  arguments => [ minutes => [0,30] ],
                                  callback => sub { warn "chime\n" });
  print 'Next chime will be at ', $t->next, "\n";

  use DateTime::Set;
  my $set = DateTime::Set->from_datetimes(dates => [
              DateTime->now->truncate(to => 'minute')->add(minutes => 1),
              DateTime->now->truncate(to => 'minute')->add(minutes => 2),
              DateTime->now->truncate(to => 'minute')->add(minutes => 3),
            ]);
  my $t2;
  $t2 = AnyEvent::DateTime->new(set => $set,
                                callback => sub {
                                  warn 'Next tick at ', $t2->next, "\n"
                                });
  print 'Next tick will be at ', $t2->next, "\n";
  AnyEvent->condvar->recv;

=head1 DESCRIPTION

This module is a wrapper to make it simpler to create various
recurrent timers with AnyEvent.  It can be used to create timers from
L<DateTime::Set> objects or from C<DateTime::Event> object.

=cut

use Class::Load qw/try_load_class/;
use AnyEvent;
use Scalar::Util qw/weaken/;
use Carp qw/croak/;

sub new {
  my $pkg = shift;
  my $self = bless { }, $pkg;

  my %p = @_;
  $self->{_callback} = $p{callback};
  if (exists $p{set}) {
    $self->{_set} = $p{set};
  } else {
    my $type = $p{type};
    my $method = $p{method} || 'new';
    my @args = @{$p{arguments} || []};
    my $module = 'DateTime::Event::'.$type;
    my ($res, $error) = try_load_class($module);
    unless ($res) { croak "Invalid timer, $module not available: $error\n"; }
    $self->{_set} = $module->$method(@args);
  }
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
  return unless (defined $next);
  my $sleep = $next->epoch - $now;
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
