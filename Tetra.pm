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

package Tetra;
use strict;

use Exporter;

$Tetra::EVT_PAGELIST_CHANGED = 6001;
$Tetra::EVT_PAGE_SELECTED = 6002;
$Tetra::EVT_BOX_SELECTED = 6003;
$Tetra::EVT_BOXVALUE_CHANGED = 6004;
$Tetra::EVT_BOX_ADDED = 6005;
$Tetra::EVT_BOX_REMOVED = 6006;

push @Exporter::EXPORT, (
	$Tetra::EVT_PAGELIST_CHANGED,
	$Tetra::EVT_PAGE_SELECTED,
	$Tetra::EVT_BOX_SELECTED,
	$Tetra::EVT_BOXVALUE_CHANGED,
	$Tetra::EVT_BOX_ADDED,
	$Tetra::EVT_BOX_REMOVED,
);

1;
