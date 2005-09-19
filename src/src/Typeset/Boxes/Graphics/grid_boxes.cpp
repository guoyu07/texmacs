
/******************************************************************************
* MODULE     : grid_boxes.cpp
* DESCRIPTION: grid boxes for the graphics
* COPYRIGHT  : (C) 2003  Henri Lesourd
*******************************************************************************
* This software falls under the GNU general public license and comes WITHOUT
* ANY WARRANTY WHATSOEVER. See the file $TEXMACS_PATH/LICENSE for more details.
* If you don't have this file, write to the Free Software Foundation, Inc.,
* 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
******************************************************************************/

#include "env.hpp"
#include "Graphics/grid.hpp"
#include "Graphics/point.hpp"
#include "Graphics/frame.hpp"
#include "Boxes/graphics.hpp"
#include "Boxes/composite.hpp"
#include "Graphics/math_util.hpp"

/******************************************************************************
* Grid boxes
******************************************************************************/

struct grid_box_rep: public box_rep {
  grid g;
  frame f;
  bool first_time;
  int dev_pixel;
  array<box> bs;
  SI un;
  grid_box_rep (
    path ip, grid g, frame f, SI un, point lim1, point lim2);
  void display (ps_device dev);
  operator tree () { return (tree)g; }
  path find_lip () { return path (-1); }
  path find_rip () { return path (-1); }
  gr_selections graphical_select (SI x, SI y, SI dist);
  gr_selections graphical_select (SI x1, SI y1, SI x2, SI y2);
  int reindex (int i, int item, int n);
};

grid_box_rep::grid_box_rep (
  path ip2, grid g2, frame f2, SI un2, point lim1, point lim2):
    box_rep (ip2), g(g2), f(f2), un(un2)
{
  first_time= true;
  point flim1= f(lim1), flim2= f(lim2);
  x1= x3= (SI) min (flim1[0], flim2[0]);
  y1= y3= (SI) min (flim1[1], flim2[1]);
  x2= x4= (SI) max (flim1[0], flim2[0]);
  y2= y4= (SI) max (flim1[1], flim2[1]);
}

void
grid_box_rep::display (ps_device dev) {
  int i;
  if (first_time || dev->pixel!=dev_pixel) {
    point p1= f [point (x1, y1)];
    point p2= f [point (x2, y2)];
    point l1= point (min (p1[0], p2[0]), min (p1[1], p2[1]));
    point l2= point (max (p1[0], p2[0]), max (p1[1], p2[1]));
    point e1= l1, e2= point (l1[0], l2[1]);
    point e3= l2, e4= point (l2[0], l1[1]);
    double L1, L2, L3, L4;
    L1= norm (e2 - e1);
    L2= norm (e3 - e2);
    L3= norm (e4 - e3);
    L4= norm (e1 - e4);
    point e1t= f (e1), e2t= f (e2);
    point e3t= f (e3), e4t= f (e4);
    double L1t, L2t, L3t, L4t;
    L1t= norm (e2t - e1t);
    L2t= norm (e3t - e2t);
    L3t= norm (e4t - e3t);
    L4t= norm (e1t - e4t);
    if (fnull (L1t, 1e-6) || fnull (L2t, 1e-6) 
     || fnull (L3t, 1e-6) || fnull (L4t, 1e-6))
      fatal_error ("One side of the grid has length zero");
    double u, u1, u2, u3, u4;
    u1= u= L1 / L1t;
    u2= min (u, L2 / L2t);
    u3= min (u, L3 / L3t);
    u4= min (u, L4 / L4t);
    array<grid_curve> grads= g->get_curves (l1, l2, u*un);

    for (i=0; i<N(grads); i++) {
      curve c= f (grads[i]->c);
      bs << curve_box (
	      decorate (ip), c, dev->pixel, dev->get_color (grads[i]->col),
	      array<bool> (0), 0, FILL_MODE_NONE, dev->white, array<box> (0));
    }
    first_time= false;
    dev_pixel= dev->pixel;
  }
  for (i=0; i<N(bs); i++)
    bs[i]->display (dev);
}

gr_selections
grid_box_rep::graphical_select (SI x, SI y, SI dist) {
  gr_selections res;
  return res;
}

gr_selections
grid_box_rep::graphical_select (SI x1, SI y1, SI x2, SI y2) {
  gr_selections res;
  return res;
}

int
grid_box_rep::reindex (int i, int item, int n) {
  return i;
}

/******************************************************************************
* User interface
******************************************************************************/

box
grid_box (path ip, grid g, frame f, SI un, point lim1, point lim2) {
  return new grid_box_rep (ip, g, f, un, lim1, lim2);
}
