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

package PageRepo;
use strict;

use File::Basename;
use IO::File;
use File::Copy;
use Tetra;

$PageRepo::singleton = undef;

sub new {
	return $PageRepo::singleton if $PageRepo::singleton;
	$PageRepo::singleton = my $self = bless({}, shift);

	$self->readIdx();

	$self->{listeners} = [];
	$self->{currentId} = -1;
	$self->{currentPage} = -1;
	$self->{currentBox} = -1;
	$self->{currentBitmap} = undef;

	$self->{tmpRect} = undef;
	$self->{tmpChars} = undef;
	
	$self->setCurrentPageIdx(0);
	return $self;
}

sub readIdx {
	my $self = shift;
	my $ttIndex = ttIndex();

	my %files = ();
	open(IDX, "< $ttIndex");
	while (<IDX>) {
		m/(\d+)\s+(\d+)\s+(.*)/;
		my ($id, $pages, $fileName) = ($1, $2, $3);
		$files{$id} = {pages => $pages, fileName => $fileName};
	}
	close(IDX);
	
	$self->{files} = \%files;
}

sub writeIdx {
	my $self = shift;
	my $ttIndex = ttIndex();

	my %files = %{$self->{files}};
	open(IDX, "> $ttIndex");
	for my $id (sort keys %files) {
		print IDX "$id $files{$id}{pages} $files{$id}{fileName}\n";
	}
	close(IDX);
}


### Adding and removing PDF files

sub addFile {
	my ($self, $fileName) = @_;

	my @tmp = (sort keys %{$self->{files}});
	my $id = $tmp[$#tmp] + 1;

	my $pages = $self->addFileInternal($id, $fileName);
	return if ($pages < 1);
	$self->{files}{$id} = {pages => $pages, fileName => $fileName};
	$self->writeIdx();
	$self->signal($Tetra::EVT_PAGELIST_CHANGED);
}

sub addFileInternal {
	my ($self, $id, $fileName) = @_;

	my $ttHome = ttHome();
	my $convert = "convert";
	my $tesseract = "tesseract";

	# Two-step conversion: PDF -> PNG -> TIF.  This prevents creating multi-page TIFs,
	# which are not handled correctly by Tesseract.

	removeId($id);
	my @pdf2png = ("$convert", "-density", "50x50", "-depth", "8", "$fileName", "${ttHome}p${id}.png");
	system(@pdf2png);
	move("${ttHome}p${id}.png", "${ttHome}p${id}-0.png") if (stat("${ttHome}p${id}.png"));

	my $pages = 0;
	opendir(DIR, $ttHome);
	while (defined (my $pngFile = readdir(DIR))) {
		next unless $pngFile =~ /^p${id}-(\d+)\.png/;
		my @png2tif = ("$convert", "${ttHome}p${id}-$1.png", "${ttHome}p${id}-$1.tif");
		system(@png2tif);
		my @tess = ("$tesseract", "${ttHome}p${id}-$1.tif", "${ttHome}p${id}-$1", "batch.nochop", "makebox");
		system(@tess);
		move("${ttHome}p${id}-$1.txt", "${ttHome}p${id}-$1.box");
		$pages++;
	}
	close(DIR);

	print "Finished processing file.\n";
	return $pages;
}

sub removeFile {
	my ($self, $id) = @_;

	my $ttHome = ttHome();
	removeId($id);

	delete($self->{files}{$id});
	$self->writeIdx();
	$self->signal($Tetra::EVT_PAGELIST_CHANGED);
	$self->setCurrentPageIdx(0) if ($self->{currentId} == $id);
}

sub removeId {
	my ($id) = @_;
	opendir(DIR, ttHome());
	while (defined (my $file = readdir(DIR))) {
		my $base = basename($file);
		$base =~ m/^p(\d+).*$/;
		next unless ((defined $1) && ("$id" eq "$1"));
		my $name = ttHome() . $file;
		# print "DEBUG: deleting $name\n";
		unlink($name);
	}
}

sub readBoxesInternal {
	my $self = shift;
	my ($id, $page) = ($self->{currentId}, $self->{currentPage});
	my $ttHome = ttHome();
	my @boxes = ();
	my $ret = open(BOX, "< ${ttHome}p${id}-${page}.box");
	if ($ret) {
		while (defined (my $line = <BOX>)) {
			my ($ch, $l, $r, $t, $b) = split(' ', $line);
			push @boxes, [$ch, $l, $r, $t, $b];
		}
	}
	close(BOX);
	$self->{files}{$id}{boxes} = {} unless (defined $self->{files}{$id}{boxes});
	$self->{files}{$id}{boxes}{$page} = \@boxes;
}

sub writeBoxes {
	my $self = shift;
	foreach my $id (sort keys %{$self->{files}}) {
		next unless (defined $self->{files}{$id}{boxes});
		my $pages = $self->{files}->{$id}{pages};
		for my $page (0 .. $pages-1) {
			$self->writeBoxesInternal($id, $page);
		}
	}
}

sub writeBoxesInternal {
	my ($self, $id, $page) = @_;
	return unless (defined $self->{files}{$id}{boxes}{$page});
	# print "DEBUG: saving p${id}-${page}.box\n";
	my @boxes = @{$self->{files}{$id}{boxes}{$page}};
	my $ttHome = ttHome();
	open(BOX, "> ${ttHome}p${id}-${page}.box");
	foreach my $boxRef (@boxes) {
		my $line = join(" ", @{$boxRef});
		print BOX "$line\n";
	}
	close(BOX);
}

### Page labels

sub getPageLabels {
	my $self = shift;
	my @labels = ();
	foreach my $id (sort keys %{$self->{files}}) {
		my $fileName = $self->{files}->{$id}{fileName};
		($fileName, $_, $_) = fileparse($fileName);
		my $pages = $self->{files}->{$id}{pages};
		for my $page (1 .. $pages) {
			push @labels, "$fileName  [$page/$pages]";
		}
	}
	return \@labels;
}

sub getCurrentPageIdx {
	my $self = shift;
	return 0 if ($self->{currentId} < 0 || $self->{currentPage} < 0);
	my $pos = 0;
	foreach my $id (sort keys %{$self->{files}}) {
		my $pages = $self->{files}->{$id}{pages};
		for my $page (0 .. ($pages - 1)) {
			return $pos if ($id == $self->{currentId} && $page == $self->{currentPage});
			$pos++;
		}
	}
	die "Internal error: obsolete (id, page) pair in model";
}

sub setCurrentPageIdx {
	my ($self, $pos) = @_;
	($self->{currentId}, $self->{currentPage}) = (-1, -1);
	if ($pos < 0) {
		$self->pageSelected();
		return;
	}
	my $cur = -1;
	foreach my $id (sort keys %{$self->{files}}) {
		my $pages = $self->{files}->{$id}{pages};
		for my $page (0 .. $pages-1) {
			next unless (++$cur == $pos);
			($self->{currentId}, $self->{currentPage}) = ($id, $page);
			$self->pageSelected();
			return;
		}
	}
}

sub pageSelected {
	my $self = shift;
	my ($id, $page) = ($self->{currentId}, $self->{currentPage});
	my $ttHome = ttHome();
	$self->{bitmap} = ($id == -1) ? undef : "${ttHome}p${id}-${page}.png";
	# print "DEBUG: current page set to $id $page\n";
	$self->signal($Tetra::EVT_PAGE_SELECTED);
	$self->setCurrentBoxIdx(0);
}

sub getCurrentPage {
	my $self = shift;
	return [$self->{currentId}, $self->{currentPage}];
}


### Box labels

sub getBoxLabels {
	my $self = shift;
	my @boxes = @{$self->getCurrentBoxes()};
	my @labels = ();
	foreach my $entry (@boxes) {
		push @labels, @{$entry}[0];
	}
	return \@labels;
}

sub getCurrentBoxIdx {
	my $self = shift;
	return $self->{currentBox};
}

sub setCurrentBoxIdx {
	my ($self, $pos) = @_;
	my @boxes = @{$self->getCurrentBoxes()};
	$pos = 0 unless defined $pos;
	$pos = $#boxes if ($pos > $#boxes);
	$pos = 0 if ($pos < 0);
	# print "DEBUG: setting to $pos\n";
	$self->{currentBox} = $pos;
	$self->signal($Tetra::EVT_BOX_SELECTED, $pos);
}

sub getCurrentBoxes {
	my $self = shift;
	my ($id, $page) = ($self->{currentId}, $self->{currentPage});
	return [] if ($id == -1);
	$self->readBoxesInternal() unless (defined $self->{files}{$id}{boxes}{$page});
	return $self->{files}{$id}{boxes}{$page};
}

sub getCurrentBox {
	my $self = shift;
	my @boxes = @{$self->getCurrentBoxes()};
	return undef if (($#boxes == -1) || ($self->{currentBox} < 0));
	return $boxes[$self->{currentBox}];
}

sub getCurrentRect {
	my $self = shift;
	my @boxes = @{$self->getCurrentBoxes()};
	return undef if (($#boxes == -1) || ($self->{currentBox} < 0));
	my @b = @{$boxes[$self->{currentBox}]};
	my $tx = $boxes[$self->{currentBox}];
	return [$b[1], $b[2], $b[3], $b[4]];
}

sub getCurrentChars {
	my $self = shift;
	my @boxes = @{$self->getCurrentBoxes()};
	return "" if ($#boxes == -1 || $self->{currentBox} < 0);
	my @currentBox = @{$boxes[$self->{currentBox}]};
	return $currentBox[0];
}

sub setTmpRect {
	my ($self, $rect) = @_;
	$self->{tmpRect} = $rect;
}

sub setTmpChars {
	my ($self, $txt) = @_;
	$self->{tmpChars} = $txt;
}

sub acceptCurrentBox {
	my $self = shift;
	my $txt = $self->{tmpChars};
	$self->{tmpRect} = $self->getCurrentRect() unless (defined $self->{tmpRect});
	return unless (defined $self->{tmpRect});
	my @rect = @{$self->{tmpRect}};
	my @boxes = @{$self->getCurrentBoxes()};
	return if ($#boxes == -1);
	my ($id, $page, $idx) = ($self->{currentId}, $self->{currentPage}, $self->{currentBox});
	if ($idx < 0) {
		$idx = 0;
	} else {
		my $changed = !($txt eq @{$boxes[$idx]}[0]);
		$self->{files}{$id}{boxes}{$page}[$idx][0] = $txt;
		$self->{files}{$id}{boxes}{$page}[$idx][1] = $rect[0];
		$self->{files}{$id}{boxes}{$page}[$idx][2] = $rect[1];
		$self->{files}{$id}{boxes}{$page}[$idx][3] = $rect[2];
		$self->{files}{$id}{boxes}{$page}[$idx][4] = $rect[3];
		$self->signal($Tetra::EVT_BOXVALUE_CHANGED, [$idx, $txt, \@rect]) if ($changed);
		$idx++ unless ($idx == $#boxes);
	}
	$self->{tmpChars} = undef;
	$self->{tmpRect} = undef;

	$self->{currentBox} = $idx;
	$self->signal($Tetra::EVT_BOX_SELECTED, $idx);
}

### Box manipulation

sub addBox {
	my $self = shift;
	my ($id, $page) = ($self->{currentId}, $self->{currentPage});
	return if ($id == -1);
	$self->readBoxesInternal() unless (defined $self->{files}{$id}{boxes}{$page});

	my $idx = -1;
	my $curBoxRef = $self->getCurrentBox();
	my @newBox = ("?", 0, 0, 10, 10);
	if (defined $curBoxRef) {
		$idx = $self->{currentBox};
		my @curBox = @{$curBoxRef};
		@newBox = ("?", $curBox[1], $curBox[2], $curBox[3], $curBox[4]);
	}
	
	my @newBoxes = ();
	my $cnt = 0;
	for my $elem (@{$self->{files}{$id}{boxes}{$page}}) {
		push @newBoxes, $elem;
		push @newBoxes, \@newBox if ($cnt++ == $idx);
	}

	push @newBoxes, \@newBox if ($#newBoxes == -1);

	$self->{files}{$id}{boxes}{$page} = \@newBoxes;
	$self->signal($Tetra::EVT_BOX_ADDED, [$idx, \@newBox]);
}

sub removeBox {
	my $self = shift;
	my ($id, $page) = ($self->{currentId}, $self->{currentPage});
	return if ($id == -1);
	return unless (defined $self->{files}{$id}{boxes}{$page});

	my $curBoxRef = $self->getCurrentBox();
	return unless (defined $curBoxRef);
	my $idx = $self->{currentBox};
	
	my @newBoxes = ();
	my $cnt = 0;
	for my $elem (@{$self->{files}{$id}{boxes}{$page}}) {
		push @newBoxes, $elem unless ($cnt++ == $idx);
	}

	$self->{files}{$id}{boxes}{$page} = \@newBoxes;
	$self->signal($Tetra::EVT_BOX_REMOVED, $idx);
}


### Initial events

sub start {
	my $self = shift;
	$self->signal($Tetra::EVT_PAGELIST_CHANGED);
	$self->signal($Tetra::EVT_PAGE_SELECTED);
	$self->setCurrentBoxIdx(0);
}


### Some constants: file names and paths

sub ttHome {
	my $ttHome;
	if (defined $ENV{HOME}) {
		$ttHome = $ENV{HOME} . "/.tthome/";
	} elsif (defined $ENV{USERPROFILE}) {
		$ttHome = $ENV{USERPROFILE} . "\\tthome\\";
	} else {
		die "Unsupported OS";
	}
	stat($ttHome) || mkdir($ttHome) || die "Cannot create $ttHome";
	return $ttHome;
}

sub ttIndex {
	my $ttIndex = ttHome() . "index.idx";
	stat($ttIndex) || open(TMP, "> $ttIndex") || die "Cannot create $ttIndex";
	close(TMP);
	return $ttIndex;
}


### Event handling and other utility functions

sub run {
	my $cmd = shift;
	print "RUNNING: $cmd\n";
	my $ret = `$cmd`;
}

sub addListener {
	my ($self, $listener) = @_;
	# print "DEBUG: adding listener $listener\n";
	push @{$self->{listeners}}, $listener;
}

sub signal {
	my ($self, $id, $data) = @_;
	# print "DEBUG: signal $id fired\n";
	foreach my $listener (@{$self->{listeners}}) {
		# print "DEBUG: sending to $listener\n";
		# &{$listener->{ttEvents}{$id}}($listener) if (defined $listener->{myEvents}{$id});
		my $event = Wx::CommandEvent->new($id, -1);
		$event->SetClientData($data);
		# $event->StopPropagation();
		$listener->AddPendingEvent($event);
	}
}

sub registerEvent {
	my ($target, $id, $subroutine) = @_;
	# $target->{ttEvents}{$id} = $subroutine;
	Wx::Event::EVT_COMMAND( $target, -1, $id, $subroutine );
}

1;
