bib2html
========

bib2html is a simple program for generating an HTML representation of
a BibTeX .bib file. It supports links to PubMed and to PDF files and a
table of contents.

Usage
-----

Type:

      bib2html -h

for help.

Limitations
-----------

It has three main limitations:

1. It does not support BibTeX style files. You are stuck with the
formatting that the code provides. However, the code is written in a
manner that somewhat mimics `.bst` files (though without the RPN!)
making it quite straightforward to modify the code to obtain different
formatting.

2. It only supports BibTeX `.bib` files in a limited format: it
requires double inverted commas around strings (not curly brackets)
and authors must be listed in the "Author1, A. B. C. and Author2,
D. E. and Author3, F." style.

3. It currently only supports `@article`, `@incollection` and `@misc`
entry types.

Additional .bib file fields
---------------------------

To support links, it provides a number of additional fields (which
will simply be ignored by BibTeX):

- `bookurl` Provides a URL to associate with a `booktitle` (in `@incollection`)
- `doi` Provides a link to dx.doi.org in a `doi:` link
- `pct` Used in `@misc` to provide extra information for patents about PCT referennces
- `pcturl` Adds a URL to the `pct` entry
- `pdf` Provides a URL for a (local) PDF
- `pubpdf` Provides a URL for the publisher's PDF
- `subpdf` Provides a URL for the PDF as submitted
- `pmid` Provides a link to PubMed in a `PMID:` link and applies the same URL to the title
- `web` Provides a link to an associated web page
- `suppmat` Provides a link to supplementary material
- `type` Used to split the entries into group. By default all entries are treated as Articles. Types of `meeting abstract`, `review`, `chapter` will all be given their own sections (and table of content entries); other types will be grouped under "Other", but the code is designed to be easily modified to add sections for other types.
- `url` Applies a URL to the title. This will take precedence over a URL generated from the PMID.



Summary of fields supported in different entry types
----------------------------------------------------

| incollection | article | misc | field     |
|--------------|---------|------|-----------|
|C             |         |      | address   |
|C             | A       | M    | author    |
|C             |         |      | booktitle |
|C             |         |      | bookurl   |
|C             | A       | M    | doi       |
|C             |         |      | edition   |
|C             |         |      | editor    |
|              | A       | M    | journal   |
|C             | A       | M    | note      |
|C             | A       | M    | pages     |
|              |         | M    | pct       |
|              |         | M    | pcturl    |
|C             | A       | M    | pdf       |
|C             | A       | M    | pmid      |
|C             |         |      | publisher |
|C             | A       | M    | pubpdf    |
|C             | A       | M    | web       |
|C             | A       | M    | subpdf    |
|C             | A       | M    | suppmat   |
|C             | A       | M    | title     |
|C             | A       | M    | type      |
|C             | A       | M    | url       |
|C             | A       | M    | volume    |
|C             | A       | M    | year      |
