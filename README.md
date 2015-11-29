# MCLRE - Multi-Contextual Learning to Rank Events

The MCLRE is an event recommendation model that takes into account multiple contextual informations (i.e. social, geographical, content and time) to recommend events in event-based social networks. It was presented in the paper [Context-Aware Event Recommendation in Event-based Social Networks](http://dl.acm.org/citation.cfm?id=2800187) published on [RecSys 2015](http://recsys.acm.org/recsys15/). The paper presentation at RecSys’15 is also available in [YouTube](https://www.youtube.com/watch?v=_5_rr1__aqw).

This repository contains the MCLRE experimental framework and you can use it to reproduce our experiments and also to evolve the model.

## Requirements

* Linux: all experiments were executed in Linux-based machines, Ubuntu distributions, more specifically

* Database: deploy a local Postgres database and use it as the initial data source to the data partitioning phase.

* Python: run `sudo pip install -r src/requirements.txt`

* R: Every library is going to be installed on demand by the framework


## Running

Follow the steps in the file: [src/run_experiment.sh](https://github.com/augustoqm/mclre/blob/master/src/run_experiment.sh)


## Dataset

For dataset access you should ask *Leandro Balby Marinho* (lbalby_at_gmail_dot_com), he will send it promptly.

Thank you for the interest and have a good job!


## Citing

```
@inproceedings{Macedo:2015:CER:2792838.2800187,
 author = {Macedo, Augusto Q. and Marinho, Leandro B. and Santos, Rodrygo L.T.},
 title = {Context-Aware Event Recommendation in Event-based Social Networks},
 booktitle = {Proceedings of the 9th ACM Conference on Recommender Systems},
 series = {RecSys '15},
 year = {2015},
 isbn = {978-1-4503-3692-5},
 location = {Vienna, Austria},
 pages = {123--130},
 numpages = {8},
 url = {http://doi.acm.org/10.1145/2792838.2800187},
 doi = {10.1145/2792838.2800187},
 acmid = {2800187},
 publisher = {ACM},
 address = {New York, NY, USA},
 keywords = {algorithms, event-based social networks, experimentation, recommender systems},
}
```

## Ackowledgments

This work was partially supported by the National Institute of Science and Technology for Software Engineering (INES), funded by CNPq and FACEPE, grants 573964/2008-4 and APQ-1037-1.03/08; and Hewlett-Packard Brasil Ltda., through the FRH-Analytics 2013 project, and used incentives from
the Brazilian Informatics Law (n. 8.2.48/1991). We also want to thank Lucas Drumond for generously sharing the implementation of his MRBPR method.

----------

MCLRE is [free software](http://www.gnu.org/philosophy/free-sw.html) ([open source software](http://opensource.org/docs/osd)), it can be used and distributed under the terms of the [GNU General Public License (GPL)](http://www.gnu.org/licenses/gpl.html).

Copyright (c) 2015-now Augusto Queiroz de Macedo

