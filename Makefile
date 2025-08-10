.PHONY: test

PLENARY ?=
RTP_CMD :=
ifneq ($(strip $(PLENARY)),)
  RTP_CMD := -c "set rtp+=$(PLENARY)"
endif

test:
	NVIM_APPNAME=llm-legion-tests \
		nvim --headless -n -u tests/minimal.vim \
		$(RTP_CMD) \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }" -c qa
