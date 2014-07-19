use strict;
use warnings;
package AnyEvent::DateTime;
$AnyEvent::DateTime::VERSION = '1.142000';
# ABSTRACT: Perl module to create AnyEvent timers from DateTime Events


use Class::Load qw/try_load_class/;
use AnyEvent;
use Scalar::Util qw/weaken/;
use Carp qw/croak/;


sub new {
  my $pkg = shift;
  my %p; @p{qw/set tick_cb empty_cb/} = @_;
  my $self = bless \%p, $pkg;
  $self->_set();
  $self
}


sub new_from_events {
  my $pkg = shift;
  my %p = @_;
  my $type = $p{type};
  my $method = $p{method} || 'new';
  my @args = @{$p{arguments} || []};
  my $module = $type =~ /^DateTime::/ ? $type : 'DateTime::Event::'.$type;
  my ($res, $error) = try_load_class($module);
  unless ($res) { croak "Invalid timer, $module not available: $error\n"; }
  my $set = $module->$method(@args);
  $pkg->new($set, $p{callback}, $p{empty_callback});
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
    $self->{set}->next(DateTime->from_epoch(epoch => $now));
  unless (defined $next) {
    $self->{empty_cb}->() if (defined $self->{empty_cb});
    return;
  }
  my $sleep = $next->epoch - $now;
  weaken $self;
  $self->{_watcher} =
    AnyEvent->timer(after => $sleep,
                    cb => sub {
                      delete $self->{_watcher};
                      my $res = $self->{tick_cb}->();
                      if ($res) {
                        $self->_set;
                      }
                    });
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

AnyEvent::DateTime - Perl module to create AnyEvent timers from DateTime Events

=head1 VERSION

version 1.142000

=head1 SYNOPSIS

  use AnyEvent::DateTime;
  use DateTime::Set;
  my $set = DateTime::Set->from_datetimes(dates => [
              DateTime->now->truncate(to => 'minute')->add(minutes => 1),
              DateTime->now->truncate(to => 'minute')->add(minutes => 2),
              DateTime->now->truncate(to => 'minute')->add(minutes => 3),
            ]);
  my $t;
  $t = AnyEvent::DateTime->new($set,
                               sub {
                                 warn 'Next tick at ', $t->next, "\n"
                               });
  print 'Next tick will be at ', $t->next, "\n";

  my $t2 =
    AnyEvent::DateTime->new_from_events(type => 'Recurrence',
                                        method => 'hourly',
                                        arguments => [ minutes => [0,30] ],
                                        callback => sub { warn "chime\n" });
  print 'Next chime will be at ', $t2->next, "\n";
  AnyEvent->condvar->recv;

=head1 DESCRIPTION

This module is a wrapper to make it simpler to create various
recurrent timers with AnyEvent.  It can be used to create timers from
L<DateTime::Set> objects or from C<DateTime::Event> object.

=head2 C<new($set, $tick_callback, $empty_callback)>

This constructor creates a wrapper around AnyEvent timers which
triggers at each time in the L<DateTime::Set>, C<$set>. When
triggered the tick callback is called. The tick callback
should return true unless it wants all subsequent timers to be cancelled.
If the set becomes empty then the optional empty callback is called.

=head2 C<new_from_events(\%parameters)>

This constructor creates a wrapper around AnyEvent timers which
triggers based on a C<DateTime::Event> module. The parameter hash
has keys:

=over 4

=item type

   The name of the C<DateTime::Event> module to construct the
   L<DateTime::Set> from. The C<DateTime::Event::> prefix may be left
   out.

=item method

  The constructor/method to call on the C<DateTime::Event> module.
  This parameter is optional and defaults to the constructor, C<new>.

=item arguments

  The arguments to pass to the method. This parameter is optional and
  defaults to the empty list.

=item callback

  The tick callback as described above.

=item empty_callback

  The optional empty callback as described above.

=head2 C<cancel()>

This method cancels any outstanding timer.

=head2 C<cancel()>

This method returns the L<DateTime> object of the next time a timer is
due to trigger.

=head1 AUTHOR

Mark Hindess <soft-cpan@temporalanomaly.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Mark Hindess.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
