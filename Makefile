#PLUGINS = get_sum
#OBJS    = get_sum.o

#MODULES = pgfake
EXTENSION = pgfake        # the extersion's name
DATA = pgfake--0.0.1.sql  # script file to install
#REGRESS = pgfake_test     # the test script file

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
