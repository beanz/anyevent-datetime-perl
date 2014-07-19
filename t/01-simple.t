#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use AnyEvent;
use Class::Load qw/try_load_class/;

use_ok('AnyEvent::DateTime');

SKIP: {
  skip 'DateTime::Event::Recurrence not available', 7
    unless (try_load_class('DateTime::Event::Recurrence'));

  my $count = 2;
  my $cv = AnyEvent->condvar;
  my $w = AnyEvent->timer(after => 5, cb => sub { $cv->send(-1) });
  my $t = AnyEvent::DateTime->new_from_events(type => 'Recurrence',
                                              method => 'secondly',
                                              arguments => [ interval => 1 ],
                                              callback => sub {
                                                my $res = $count;
                                                $count--;
                                                $cv->send($res);
                                                return $res;
                                              });
  ok($t, 'timer created');
  my $now = AnyEvent->now;
  my $next = $t->next->epoch;
  ok($next > $now, q!... 'next' later than now!);
  ok($next < $now+1, q!... 'next' less than now+1!);
  is($cv->recv, 2, '... timer count=2');
  $cv = AnyEvent->condvar;
  is($cv->recv, 1, '... timer count=1');
  $cv = AnyEvent->condvar;
  is($cv->recv, 0, '... timer count=0');
  $cv = AnyEvent->condvar;
  is($cv->recv, -1, '... timer removed');

  $cv = AnyEvent->condvar;
  $w = AnyEvent->timer(after => 2, cb => sub { $cv->send(-1) });
  $t = AnyEvent::DateTime->new_from_events(type => 'Recurrence',
                                           method => 'secondly',
                                           arguments => [ interval => 1 ],
                                           callback => sub {
                                             $cv->send(1);
                                             1;
                                           });
  ok($t, 'timer created');
  undef $t;
  is($cv->recv, -1, '... timer cancelled');
};

eval { AnyEvent::DateTime->new_from_events(type => 'Lunch'); };
like($@, qr!^Invalid timer, DateTime::Event::Lunch not available:!,
     'invalid event module');

done_testing;
