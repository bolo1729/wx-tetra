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

package EditFrame;
use strict;
use base 'Wx::Frame';

use Wx qw(:everything);
use File::Basename;
use IO::File;
use PdfFrame;
use ImageViewer;
use Tetra;

sub new {
	my ($class, $parent, $model) = @_;
	my $self = $class->SUPER::new($parent, -1, 'Tetra: Tesseract Training', [-1, -1], [1000, 650]);
	$self->init($model);
	return $self;
}

sub init {
	my ($self, $model) = @_;
	$self->{model} = $model;
	$model->addListener($self);

	my $panel = Wx::Panel->new($self, -1);
	$self->{panel} = $panel;

	$self->{input} = Wx::TextCtrl->new($panel, -1, "", [10, 600], [90, 30], wxTE_PROCESS_ENTER);
	$self->{btnNext} = Wx::Button->new($panel, -1, "Change", [110, 600], [90, 30]);
	$self->{page} = Wx::Choice->new($panel, -1, [300, 600], [240, -1], []);
	$self->{btnSave} = Wx::Button->new($panel, -1, "Save", [640, 600], [120, -1]);
	$self->{btnPdf} = Wx::Button->new($panel, -1, "Manage PDFs", [770, 600], [120, -1]);
	$self->{btnClose} = Wx::Button->new($panel, -1, "Close", [900, 600], [90, -1]);
	$self->{boxes} = Wx::ListBox->new($panel, -1, [10, 10], [100, 530], []);
	$self->{btnAdd} = Wx::Button->new($panel, -1, "+", [10, 550], [40, -1]);
	$self->{btnRemove} = Wx::Button->new($panel, -1, "-", [60, 550], [40, -1]);

	$self->{imageViewer} = ImageViewer->new($panel, -1, [120, 10], [870, 580]);
	$self->{imageViewer}->{model} = $model;
	$model->addListener($self->{imageViewer});

	$self->initEvents();
	$model->start();
	return $self;
}

sub initEvents {
	my $self = shift;

	Wx::Event::EVT_BUTTON( $self, $self->{btnClose}, \&onBtnClose );
	Wx::Event::EVT_CLOSE( $self, \&onClose );
	Wx::Event::EVT_CHOICE( $self, $self->{page}, \&onPageChoice );
	Wx::Event::EVT_LISTBOX( $self, $self->{boxes}, \&onListSelected );
	Wx::Event::EVT_TEXT_ENTER( $self, $self->{input}, \&onBtnNext );
	Wx::Event::EVT_BUTTON( $self, $self->{btnNext}, \&onBtnNext );
	Wx::Event::EVT_BUTTON( $self, $self->{btnAdd}, \&onBtnAdd );
	Wx::Event::EVT_BUTTON( $self, $self->{btnRemove}, \&onBtnRemove );
	Wx::Event::EVT_BUTTON( $self, $self->{btnPdf}, \&onBtnPdf );
	Wx::Event::EVT_BUTTON( $self, $self->{btnSave}, \&onBtnSave );

	PageRepo::registerEvent( $self, $Tetra::EVT_PAGE_SELECTED, \&modelPageSelected );
	PageRepo::registerEvent( $self, $Tetra::EVT_PAGELIST_CHANGED, \&modelPageListChanged );
	PageRepo::registerEvent( $self, $Tetra::EVT_BOX_SELECTED, \&modelBoxSelected );
	PageRepo::registerEvent( $self, $Tetra::EVT_BOXVALUE_CHANGED, \&modelBoxValueChanged );
	PageRepo::registerEvent( $self, $Tetra::EVT_BOX_ADDED, \&modelBoxAdded );
	PageRepo::registerEvent( $self, $Tetra::EVT_BOX_REMOVED, \&modelBoxRemoved );

}

sub modelPageListChanged {
	my $self = shift;
	my @labels = @{$self->{model}->getPageLabels()};
	my $panel = $self->{panel};
	$self->{page}->Clear();
	for my $label (@labels) {
		$self->{page}->Append($label);
	}
	my $pos = $self->{model}->getCurrentPageIdx();
	$self->{page}->SetSelection($pos);
}

sub onPageChoice {
	my $self = shift;
	my $pos = $self->{page}->GetSelection();
	$self->{model}->setCurrentPageIdx($pos);
}

sub modelPageSelected {
	my $self = shift;
	my @labels = @{$self->{model}->getBoxLabels()};
	$self->{boxes}->Set(\@labels);
}

sub onListSelected {
	my $self = shift;
	my $selection = $self->{boxes}->GetSelections();
	$selection = 0 unless (defined $selection);
	$self->{model}->setCurrentBoxIdx($selection);
}

sub modelBoxSelected {
	my ($self, $event) = @_;
	my $newPos = $event->GetClientData();
	my $oldPos = $self->{boxes}->GetSelections();
	$self->{boxes}->SetSelection($newPos) if ((! defined $oldPos) || ($newPos != $oldPos));

	my $txt = $self->{model}->getCurrentChars();
	$self->{input}->ChangeValue($txt);
	$self->{input}->SetFocus();
	$self->{input}->SetSelection(-1, -1);
}

sub onBtnNext {
	my $self = shift;
	my $txt = $self->{input}->GetValue();
	$self->{model}->setTmpChars($txt);
	$self->{model}->acceptCurrentBox();
}

sub modelBoxValueChanged {
	my ($self, $event) = @_;
	my ($pos, $txt, $rect) = @{$event->GetClientData()};
	$self->{boxes}->SetString($pos, $txt);
}

sub onBtnClose {
	my $self = shift;
	$self->Close();
}

sub onClose {
	my ($self, $event) = @_;
	my $dialog = Wx::MessageDialog->new($self, "Do you want to save your work before quitting?", "Quit", wxYES_NO | wxCANCEL);
	my $choice = $dialog->ShowModal();
	if ($choice == wxID_CANCEL && $event->CanVeto()) {
		$event->Veto();
		return;
	}
	$self->{model}->writeBoxes() if ($choice == wxID_YES);
	$self->Destroy();
}

sub onBtnPdf {
	my $self = shift;
	my $frame = PdfFrame->newFrame($self->{model});
	$frame->ShowModal();
	$frame->Destroy();
}

sub onBtnAdd {
	my $self = shift;
	$self->{model}->addBox();
}

sub modelBoxAdded {
	my ($self, $event) = @_;
	my ($idx, $boxRef) = @{$event->GetClientData()};
	$self->{boxes}->InsertItems([@{$boxRef}[0]], $idx + 1);
}

sub onBtnRemove {
	my $self = shift;
	$self->{model}->removeBox();
}

sub modelBoxRemoved {
	my ($self, $event) = @_;
	my $idx = $event->GetClientData();
	$self->{boxes}->Delete($idx);
	$self->{model}->setCurrentBoxIdx($idx);
}

sub onBtnSave {
	my $self = shift;
	$self->{model}->writeBoxes();
}


1;
