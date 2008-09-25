# Tetra: Tesseract Training Application
# Copyright (C) 2008  Lukasz Bolikowski <bolo@icm.edu.pl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ImageViewer;
use strict;
use base 'Wx::ScrolledWindow';
use Wx qw(:everything);
use Tetra qw(:everything);

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->SetScrollbars(20, 20, 150, 200);
	$self->{canvas} = Wx::Panel->new($self, -1, [0, 0], [3000, 4000]);
	$self->{canvas}->{imgViewer} = $self;

	Wx::Event::EVT_PAINT($self->{canvas}, \&onPaint);
	Wx::Event::EVT_LEFT_DOWN($self->{canvas}, \&onLeftDown);
	Wx::Event::EVT_LEFT_UP($self->{canvas}, \&onLeftUp);
	Wx::Event::EVT_MOTION($self->{canvas}, \&onMotion);

	PageRepo::registerEvent( $self, $Tetra::EVT_PAGE_SELECTED, \&modelPageSelected );
	PageRepo::registerEvent( $self, $Tetra::EVT_BOX_SELECTED, \&modelBoxSelected );
	return $self;
}

sub repaint {
	my $viewer = shift;
	$viewer->{canvas}->Refresh(1);
}

sub onPaint {
	my $canvas = shift;
	my $paintDC = Wx::PaintDC->new($canvas);
	my $viewer = $canvas->{imgViewer};
	
	return unless (ref $viewer->{bitmap});
	$paintDC->DrawBitmap($viewer->{bitmap}, 0, 0, 0);
	
	return unless (ref $viewer->{rect});
	my $pen = Wx::Pen->new(Wx::wxRED, 2, Wx::wxSOLID);
	$paintDC->SetPen($pen);
	my ($l, $b, $r, $t) = @{$viewer->{rect}};
	my $h = $viewer->{bitmap}->GetHeight();
	# print "DEBUG $l $b $r $t\n";
	$paintDC->DrawLine($l, $h-$b, $r, $h-$b);
	$paintDC->DrawLine($l, $h-$t, $r, $h-$t);
	$paintDC->DrawLine($l, $h-$b, $l, $h-$t);
	$paintDC->DrawLine($r, $h-$b, $r, $h-$t);
}

sub modelPageSelected {
	my ($viewer, $event) = @_;
	my $png = $viewer->{model}->{bitmap};
	$viewer->{bitmap} = (! defined $png) ? undef :
			Wx::Bitmap->new($png, wxBITMAP_TYPE_PNG);
	$viewer->{rect} = undef;
	$viewer->repaint();
	$event->Skip(1);
}

sub modelBoxSelected {
	my ($viewer, $event) = @_;
	$viewer->{rect} = $viewer->{model}->getCurrentRect();
	$viewer->repaint();
	$event->Skip(1);
}

sub onLeftDown {
	my $canvas = shift;
	my $event = shift;
	my $viewer = $canvas->{imgViewer};
	$viewer->{tmpStart} = [$event->GetX(), $event->GetY()];
}

sub onLeftUp {
	my $viewer = shift->{imgViewer};
	my $event = shift;
	onMotion($viewer, $event);
	$viewer->{model}->setTmpRect($viewer->{rect});
	delete($viewer->{tmpStart});
}

sub onMotion {
	my $canvas = shift;
	my $event = shift;
	my $viewer = $canvas->{imgViewer};

	return unless (ref $viewer->{bitmap});
	return unless (ref $viewer->{tmpStart});

	my @s = @{$viewer->{tmpStart}};
	my @e = @{[$event->GetX(), $event->GetY()]};
	
	my $h = $viewer->{bitmap}->GetHeight();
	my ($l, $r) = (min($s[0], $e[0]), max($s[0], $e[0]));
	my ($b, $t) = ($h-max($s[1], $e[1]), $h-min($s[1], $e[1]));
	$viewer->{rect} = [$l, $b, $r, $t];
	$viewer->repaint();
}

sub min { return ($_[0] < $_[1]) ? $_[0] : $_[1]; }
sub max { return ($_[0] > $_[1]) ? $_[0] : $_[1]; }

1;
