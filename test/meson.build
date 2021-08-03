testclient_src = files([
  'testclient.vala',
])

executable('vls-testclient',
  dependencies: deps,
  sources: [testclient_src, extra_vala_sources],
  install: false)


formatting_tester_src = files([
  'formattingtest.vala'
])

executable('formatting_tester',
  dependencies: deps,
  sources: [formatting_tester_src, formatting_visitor]
)