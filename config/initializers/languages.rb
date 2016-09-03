LANGUAGES = [
  RUBY = "ruby",
  PYTHON = "python",
  GO = "go",
  SWIFT = "swift",
  C = "c"
]

LANGUAGE_VERSIONS = {
  RUBY => ["2.3.1", "2.2.5", "2.1.10"],
  PYTHON => ["2.7.12", "3.3.6", "3.4.5"],
  GO => ["1.7.0"],
  SWIFT => ["latest"],
  C => ["latest"],
}

DOCKER_IMAGES = {
  RUBY => "koderunr-ruby",
  PYTHON => "koderunr-python",
  GO => "koderunr-go",
  SWIFT => "koderunr-swift",
  C => "koderunr-c",
}
