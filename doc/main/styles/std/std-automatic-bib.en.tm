<TeXmacs|1.0.3.7>

<style|tmdoc>

<\body>
  <tmdoc-title|Bibliographies>

  The following macros may be used in the main text for citations to entries
  in a bibliographic database.

  <\explain|<explain-macro|cite|ref-1|<with|mode|math|\<cdots\>>|ref-n>>
    Each argument <src-arg|ref-i> is a citation corresponding to an item in a
    BiB-<TeX> file. The citations are displayed in the same way as they are
    referenced in the bibliography and they also provide hyperlinks to the
    corresponding references. The citations are displayed as question marks
    if you did not generate the bibliography.
  </explain>

  <\explain|<explain-macro|nocite|ref-1|<with|mode|math|\<cdots\>>|ref-n>>
    Similar as <markup|cite>, but the citations are not displayed in the main
    text.
  </explain>

  <\explain|<explain-macro|cite-detail|ref|info>>
    A bibliographic reference <src-arg|ref> like above, but with some
    additional information <src-arg|info>, like a chapter or a page number.
  </explain>

  The following macros may be redefined if you want to customize the
  rendering of citations or entries in the generated bibliography:

  <\explain|<explain-macro|render-cite|ref>>
    Macro for rendering a citation <src-arg|ref> at the place where the
    citation is made using <markup|cite>. The <src-arg|content> may be a
    single reference, like ``TM98'', or a list of references, like ``Euler1,
    Gauss2''.
  </explain>

  <\explain|<explain-macro|render-cite-detail|ref|info>>
    Similar to <markup|render-cite>, but for detailed citations made with
    <markup|cite-detail>.
  </explain>

  <\explain|<explain-macro|render-bibitem|content>>
    At the moment, bibliographies are generated by Bib<TeX> and imported into
    <TeXmacs>. The produced bibliography is a list of bibliographic items
    with are based on special <LaTeX>-specific macros (<markup|bibitem>,
    <markup|block>, <markup|protect>, <abbr|etc.>). These macros are all
    defined internally in <TeXmacs> and eventually boil down to calls of the
    <markup|render-bibitem>, which behaves in a similar way as
    <markup|item*>, and which may be redefined by the user.
  </explain>

  <tmdoc-copyright|1998--2002|Joris van der Hoeven>

  <tmdoc-license|Permission is granted to copy, distribute and/or modify this
  document under the terms of the GNU Free Documentation License, Version 1.1
  or any later version published by the Free Software Foundation; with no
  Invariant Sections, with no Front-Cover Texts, and with no Back-Cover
  Texts. A copy of the license is included in the section entitled "GNU Free
  Documentation License".>
</body>

<\initial>
  <\collection>
    <associate|language|english>
    <associate|page-bot|30mm>
    <associate|page-even|30mm>
    <associate|page-odd|30mm>
    <associate|page-reduce-bot|15mm>
    <associate|page-reduce-left|25mm>
    <associate|page-reduce-right|25mm>
    <associate|page-reduce-top|15mm>
    <associate|page-right|30mm>
    <associate|page-top|30mm>
    <associate|page-type|a4>
    <associate|par-width|150mm>
    <associate|sfactor|4>
  </collection>
</initial>