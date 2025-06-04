---
title: >
    $title$
    
author: $authornames_formatted$
date: $date$
publisher: Lois & Clark Fanfic Archive
---

# Preface {.hidden-h1}

::: {.title}
$title$
:::

::: {.author}
By $authors_formatted$
:::

::: {.metadata}
Submitted: $dateformatted$

Rated: $rating$

Summary: $summary$

Story Size: $length.words$ words ($length.text$ as text)
:::

$if(preface)$
$preface$
$endif$

$if(first_heading)$
$else$
# Story {.hidden-h1}
$endif$

$body$