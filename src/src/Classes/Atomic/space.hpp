
/******************************************************************************
* MODULE     : space.hpp
* DESCRIPTION: spacing
* COPYRIGHT  : (C) 1999  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license and comes WITHOUT
* ANY WARRANTY WHATSOEVER. See the file $TEXMACS_PATH/LICENSE for more details.
* If you don't have this file, write to the Free Software Foundation, Inc.,
* 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
******************************************************************************/

#ifndef SPACE_H
#define SPACE_H
#include "tree.hpp"

class space_rep: concrete_struct {
public:
  SI min;
  SI def;
  SI max;

  space_rep (SI def);
  space_rep (SI min, SI def, SI max);

  friend class space;
};

class space {
  CONCRETE(space);
  space (SI def=0);
  space (SI min, SI def, SI max);
  operator tree ();
  inline void operator += (space spc) {
    rep->min += spc->min;
    rep->def += spc->def;
    rep->max += spc->max; }
};
CONCRETE_CODE(space);

bool operator == (space spc1, space spc2);
bool operator != (space spc1, space spc2);
ostream& operator << (ostream& out, space spc);
space copy (space spc);
space operator + (space spc1, space spc2);
space operator - (space spc1, space spc2);
space operator * (int i, space spc);
space operator / (space spc, int i);
space max (space spc1, space spc2);

#endif // defined SPACE_H
