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

package TrainingApp;
use strict;

use Wx;
use EditFrame;
use PageRepo;

use base 'Wx::App';

sub OnInit {
	Wx::InitAllImageHandlers();
	my $pageRepo = PageRepo->new();
	my $frame = EditFrame->new(undef, $pageRepo);
	$frame->Show(1);
}

1;
