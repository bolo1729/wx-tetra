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

package PdfFrame;
use strict;
use base 'Wx::Dialog';
use File::Basename;
use Wx qw(:everything);

sub new {
	my $class = shift;
	my $pageRepo = shift;
	my $self = $class->SUPER::new(@_);

	my $panel = Wx::Panel->new($self, -1, [-1, -1], [500, 310]);

	$self->{model} = $pageRepo;

	my $labelsRef = $self->getFileLabels();

	$self->{txt} = Wx::StaticText->new($panel, 1, "Current PDF files:", [10, 10], [-1, -1]);
	$self->{list} = Wx::ListBox->new($panel, 2, [10, 30], [480, 200], $labelsRef);
	$self->{btnAdd} = Wx::Button->new($panel, 3, "+", [10, 250], [50, -1]);
	$self->{btnRemove} = Wx::Button->new($panel, 4, "-", [70, 250], [50, -1]);
	$self->{btnClose} = Wx::Button->new($panel, 5, "Close", [390, 250], [100, -1]);
	
	Wx::Event::EVT_BUTTON($self, $self->{btnClose}, \&onBtnClose);
	Wx::Event::EVT_BUTTON($self, $self->{btnAdd}, \&onBtnAdd);
	Wx::Event::EVT_BUTTON($self, $self->{btnRemove}, \&onBtnRemove);
	
	return $self;
}

sub getFileLabels {
	my $self = shift;
	my @labels = ();
	foreach my $id (sort keys %{$self->{model}->{files}}) {
		my $fileName = $self->{model}->{files}->{$id}{fileName};
		($fileName, $_, $_) = fileparse($fileName);
		my $pages = $self->{model}->{files}->{$id}{pages};
		push @labels, "$fileName ($pages pages)";
	}
	return \@labels;
}

sub getFileIds {
	my $self = shift;
	my @ids = (sort keys %{$self->{model}->{files}});
	return \@ids;
}

sub onBtnClose {
	my $self = shift;
	$self->Close();
}

sub onBtnAdd {
	my $self = shift;
	my $dialog = Wx::FileDialog->new($self, "Add a PDF file", "", "", "PDF files (*.pdf)|*.pdf");
	my $response = $dialog->ShowModal();
	return if ($response == Wx::wxID_CANCEL);

	my $path = $dialog->GetPath();
	$self->{model}->addFile($path);

	$self->{list}->Set($self->getFileLabels());
}

sub onBtnRemove {
	my $self = shift;
	my $selection = $self->{list}->GetSelections();
	return unless (defined $selection);
	my $id = @{$self->getFileIds()}[$selection];
	$self->{model}->removeFile($id);
	$self->{list}->Set($self->getFileLabels());
}

sub newFrame {
	my $class = shift;
	my $pageRepo = shift;
	my $parent = shift || undef;
	my $frame = PdfFrame->new($pageRepo, $parent, -1, 'PDF files', [-1, -1], [500, 310]);
	return $frame;
}

1;
