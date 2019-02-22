PY=python3
PELICAN?=pelican
PELICANOPTS?=

BASEDIR=$(CURDIR)
INPUTDIR=$(BASEDIR)/content
OUTPUTDIR=$(BASEDIR)/output
CONFFILE=$(BASEDIR)/pelicanconf.py
PUBLISHCONF=$(BASEDIR)/publishconf.py

help:
	@echo 'Makefile for a pelican Web site                                        '
	@echo '                                                                       '
	@echo 'Usage:                                                                 '
	@echo '   make html                        (re)generate the web site          '
	@echo '   make clean                       remove the generated files         '
	@echo '   make regenerate                  regenerate files upon modification '
	@echo '   make publish                     generate using production settings '
	@echo '   make serve                       serve site at http://localhost:8000'
	@echo '   make devserver                   start/restart develop_server.sh    '
	@echo '   make stopserver                  stop local server                  '
	@echo '   ssh_upload                       upload the web site via SSH        '
	@echo '   rsync_upload                     upload the web site via rsync+ssh  '
	@echo '   dropbox_upload                   upload the web site via Dropbox    '
	@echo '   ftp_upload                       upload the web site via FTP        '
	@echo '   s3_upload                        upload the web site via S3         '
	@echo '   github                           upload the web site via gh-pages   '
	@echo '                                                                       '


html:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

drafts:
	cp -r drafts content

rmdrafts:
	[ ! -d content/drafts ] || rm -rf content/drafts

clean:
	[ ! -d $(OUTPUTDIR) ] || find $(OUTPUTDIR) -not -type d -not -wholename "*/.git*"  -not -iname "*.pdf" -not -iname "*.png" -delete


ZH=$(shell find content -iname "*.zh.rst")

regenerate: 
	$(PELICAN) -r $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

serve:
	cd $(OUTPUTDIR) && $(PY) -m pelican.server

devserver:
	$(BASEDIR)/develop_server.sh restart

stopserver:
	kill -9 `cat pelican.pid`
	kill -9 `cat srv.pid`
	@echo 'Stopped Pelican and SimpleHTTPServer processes running in background.'

theme:
	(cd theme && (scons -Q || make) )

publish: rmdrafts
	[ ! -d $(OUTPUTDIR) ] || (cd $(OUTPUTDIR) && find -not -type d -not -wholename "*/.git*"  -not -iname "*.pdf" -not -iname "*.png" -delete)
	echo $(SITEURL) > content/static/CNAME
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(PUBLISHCONF) $(PELICANOPTS)
	$(MAKE) rsthtml

rsthtml:
	(cd output && find -iname "*.rst" | parallel -I@ pygmentize -f html -o @.html @)

ssh_upload:
	$(MAKE) publish
	scp -P $(SSH_PORT) -r $(OUTPUTDIR)/* $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR)

rsync_upload:
	$(MAKE) publish
	rsync -e "ssh -p $(SSH_PORT)" -P -rvz --delete $(OUTPUTDIR)/ $(SSH_USER)@$(SSH_HOST):$(SSH_TARGET_DIR) --cvs-exclude

ftp_upload:
	$(MAKE) publish
	lftp ftp://$(FTP_USER)@$(FTP_HOST) -e "mirror -R $(OUTPUTDIR) $(FTP_TARGET_DIR) ; quit"

s3_upload:
	$(MAKE) publish
	s3cmd sync $(OUTPUTDIR)/ s3://$(S3_BUCKET) --acl-public --delete-removed

github:
	(cd $(OUTPUTDIR) && git checkout master)
	$(MAKE) renderpdf
	env SITEURL="sak.uy" $(MAKE) publish
	(cd $(OUTPUTDIR) && git add -A . && git commit -m "update html" && git push --quiet)

gitcafe:
	(cd $(OUTPUTDIR) && git checkout gitcafe-pages)
	env SITEURL="sakuy.gitcafe.io" $(MAKE) publish
	(cd $(OUTPUTDIR) && git add . && git commit -m "update" && git push -u gitcafe gitcafe-pages --quiet)

.PHONY: html help clean regenerate serve devserver publish ssh_upload rsync_upload dropbox_upload ftp_upload s3_upload github theme drafts rmdrafts rsthtml
