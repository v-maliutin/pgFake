#MODULES = pgsqlmock
EXTENSION = pgsqlmock        # the extersion's name
DATA = pgsqlmock--1.0.0.sql pgsqlmock--1.0.0--1.0.1.sql  # script file to install
REGRESS = viewmock funcmock faketable    # the test script file

# for posgres build
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# override CFLAGS += -I$(top_srcdir)/src/pl/plpgsql/src

# all:    $(addsuffix $(DLSUFFIX), $(SHAREDLIBS)) $(addsuffix $(DLSUFFIX), $(PLUGINS)) $(INSTALL_scripts)

# install: all installdirs
# 	$(INSTALL_SHLIB) $(addsuffix $(DLSUFFIX), $(PLUGINS)) '$(DESTDIR)$(pkglibdir)/plugins/'

# installdirs:
# 	$(MKDIR_P)$(mkinstalldirs) $(DESTDIR)$(pkglibdir)/plugins

# uninstall:
# 	rm -f $(addprefix '$(DESTDIR)$(pkglibdir)/plugins'/, $(addsuffix $(DLSUFFIX), $(PLUGINS)))
