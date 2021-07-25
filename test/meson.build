testclient_src = files([
  'testclient.vala',
])

executable('vls-testclient',
  dependencies: deps,
  sources: [testclient_src, extra_vala_sources],
  install: false)

test('tokenizer_test', executable('tokenizer_test', sources: ['tokenizer_test.vala', formatter_source], dependencies: deps))