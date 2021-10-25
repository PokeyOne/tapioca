# typed: true
# frozen_string_literal: true

require "cli_spec"

module Tapioca
  class GemSpec < CliSpec
    include TemplateHelper

    FOO_RBI = <<~CONTENTS
      # typed: true

      # DO NOT EDIT MANUALLY
      # This is an autogenerated file for types exported from the `foo` gem.
      # Please instead update this file by running `bin/tapioca gem foo`.

      module Foo
        class << self
          def bar(a = T.unsafe(nil), b: T.unsafe(nil), **opts); end
        end
      end

      Foo::PI = T.let(T.unsafe(nil), Float)
    CONTENTS

    BAR_RBI = <<~CONTENTS
      # typed: true

      # DO NOT EDIT MANUALLY
      # This is an autogenerated file for types exported from the `bar` gem.
      # Please instead update this file by running `bin/tapioca gem bar`.

      module Bar
        class << self
          def bar(a = T.unsafe(nil), b: T.unsafe(nil), **opts); end
        end
      end

      Bar::PI = T.let(T.unsafe(nil), Float)
    CONTENTS

    BAZ_RBI = <<~CONTENTS
      # typed: true

      # DO NOT EDIT MANUALLY
      # This is an autogenerated file for types exported from the `baz` gem.
      # Please instead update this file by running `bin/tapioca gem baz`.

      module Baz; end

      class Baz::Role
        include ::SmartProperties
        extend ::SmartProperties::ClassMethods
      end

      class Baz::Test
        def fizz; end
      end
    CONTENTS

    describe("#gem") do
      describe("flags") do
        it "must show an error if --all is supplied with arguments" do
          output = tapioca("gem --all foo")

          assert_equal(<<~OUTPUT, output)
            Option '--all' must be provided without any other arguments
          OUTPUT
        end

        it "must show an error if --verify is supplied with arguments" do
          output = tapioca("gem --all foo")

          assert_equal(<<~OUTPUT, output)
            Option '--all' must be provided without any other arguments
          OUTPUT
        end

        it "must show an error if both --all and --verify are supplied" do
          output = tapioca("gem --all --verify")

          assert_equal(<<~OUTPUT, output)
            Options '--all' and '--verify' are mutually exclusive
          OUTPUT
        end
      end

      describe("generate") do
        before do
          tapioca("init")
        end

        it "must generate a single gem RBI" do
          output = tapioca("gem foo")

          assert_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
                  create  #{outdir}/foo@0.0.1.rbi
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_equal(FOO_RBI, File.read("#{outdir}/foo@0.0.1.rbi"))

          refute_path_exists("#{outdir}/bar@0.3.0.rbi")
          refute_path_exists("#{outdir}/baz@0.0.2.rbi")
        end

        it "must generate RBI for a default gem" do
          output = tapioca("gem did_you_mean")

          assert_includes(output, <<~OUTPUT)
            Processing 'did_you_mean' gem:
              Compiling did_you_mean, this may take a few seconds...   Done
          OUTPUT

          did_you_mean_rbi_file = T.must(Dir.glob("#{outdir}/did_you_mean@*.rbi").first)
          assert_includes(File.read(did_you_mean_rbi_file), "module DidYouMean")
        end

        it "must generate gem RBI in correct output directory" do
          output = tapioca("gem foo", use_default_outdir: true)

          assert_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
          OUTPUT

          assert_path_exists("#{repo_path}/sorbet/rbi/gems/foo@0.0.1.rbi")
          assert_equal(FOO_RBI, File.read("#{repo_path}/sorbet/rbi/gems/foo@0.0.1.rbi"))

          refute_path_exists("#{repo_path}/sorbet/rbi/gems/bar@0.3.0.rbi")
          refute_path_exists("#{repo_path}/sorbet/rbi/gems/baz@0.0.2.rbi")
        end

        it "must perform postrequire properly" do
          output = tapioca("gem foo --postrequire #{repo_path / "postrequire.rb"}")

          assert_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_equal(template(<<~CONTENTS), File.read("#{outdir}/foo@0.0.1.rbi"))
            #{FOO_RBI.rstrip}
            class Foo::Secret; end
            <% if ruby_version(">= 2.4.0") %>
            Foo::Secret::VALUE = T.let(T.unsafe(nil), Integer)
            <% else %>
            Foo::Secret::VALUE = T.let(T.unsafe(nil), Fixnum)
            <% end %>
          CONTENTS

          refute_path_exists("#{outdir}/bar@0.3.0.rbi")
          refute_path_exists("#{outdir}/baz@0.0.2.rbi")
        end

        it "explains what went wrong when it can't load the postrequire properly" do
          output = tapioca("gem foo --postrequire #{repo_path / "postrequire_faulty.rb"}")

          output.sub!(%r{/.*/postrequire_faulty\.rb}, "/postrequire_faulty.rb")
          assert_includes(output, <<~OUTPUT)
            Requiring all gems to prepare for compiling... \n
            LoadError: cannot load such file -- foo/will_fail

            Tapioca could not load all the gems required by your application.
            If you populated /postrequire_faulty.rb with `bin/tapioca require`
            you should probably review it and remove the faulty line.
          OUTPUT
        end

        it "must not include `rbi` definitions into `tapioca` RBI" do
          output = tapioca("gem")

          assert_includes(output, <<~OUTPUT)
            Compiling tapioca, this may take a few seconds...   Done
          OUTPUT

          tapioca_rbi_file = T.must(Dir.glob("#{outdir}/tapioca@*.rbi").first)
          refute_includes(File.read(tapioca_rbi_file), "class RBI::Module")
        end

        it "must generate multiple gem RBIs" do
          output = tapioca("gem foo bar")

          assert_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
          OUTPUT

          assert_includes(output, <<~OUTPUT)
            Processing 'bar' gem:
              Compiling bar, this may take a few seconds...   Done
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_path_exists("#{outdir}/bar@0.3.0.rbi")

          assert_equal(FOO_RBI, File.read("#{outdir}/foo@0.0.1.rbi"))
          assert_equal(BAR_RBI, File.read("#{outdir}/bar@0.3.0.rbi"))

          refute_path_exists("#{outdir}/baz@0.0.2.rbi")
        end

        it "must generate RBIs for all gems in the Gemfile" do
          output = tapioca("gem --all")

          assert_includes(output, <<~OUTPUT)
            Processing 'bar' gem:
              Compiling bar, this may take a few seconds...   Done
          OUTPUT

          assert_includes(output, <<~OUTPUT)
            Processing 'baz' gem:
              Compiling baz, this may take a few seconds...   Done
          OUTPUT

          assert_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")

          assert_equal(FOO_RBI, File.read("#{outdir}/foo@0.0.1.rbi"))
          assert_equal(BAR_RBI, File.read("#{outdir}/bar@0.3.0.rbi"))
          assert_equal(BAZ_RBI, File.read("#{outdir}/baz@0.0.2.rbi"))
        end

        it "must not generate RBIs for missing gem specs" do
          output = tapioca("gem")

          missing_spec = "    completed with missing specs:   minitest-excludes (2.0.1)"
          assert_includes(output, missing_spec)

          compiling_spec = "  Compiling minitest-excludes, this may take a few seconds"
          refute_includes(output, compiling_spec)
        end

        it "must generate git gem RBIs with source revision numbers" do
          output = tapioca("gem ast")

          assert_includes(output, <<~OUTPUT)
            Processing 'ast' gem:
              Compiling ast, this may take a few seconds...   Done
          OUTPUT

          assert_path_exists("#{outdir}/ast@2.4.1-e07a4f66e05ac7972643a8841e336d327ea78ae1.rbi")
        end

        it "must respect exclude option" do
          output = tapioca("gem --all --exclude foo bar")

          refute_includes(output, <<~OUTPUT)
            Processing 'bar' gem:
              Compiling bar, this may take a few seconds...   Done
          OUTPUT

          assert_includes(output, <<~OUTPUT)
            Processing 'baz' gem:
              Compiling baz, this may take a few seconds...   Done
          OUTPUT

          refute_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
          OUTPUT

          refute_path_exists("#{outdir}/foo@0.0.1.rbi")
          refute_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")

          assert_equal(BAZ_RBI, File.read("#{outdir}/baz@0.0.2.rbi"))
        end

        it "does not crash when the extras gem is loaded" do
          File.write(repo_path / "sorbet/tapioca/require.rb", 'require "extras/shell"')
          output = tapioca("gem foo")

          assert_includes(output, <<~OUTPUT)
            Processing 'foo' gem:
              Compiling foo, this may take a few seconds...   Done
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_equal(FOO_RBI, File.read("#{outdir}/foo@0.0.1.rbi"))

          File.delete(repo_path / "sorbet/tapioca/require.rb")
        end
      end

      describe("sync") do
        it "must perform no operations if everything is up-to-date" do
          tapioca("gem")

          output = tapioca("gem")

          refute_includes(output, "-- Removing:")
          refute_includes(output, "      create")
          refute_includes(output, "-> Moving:")

          assert_includes(output, <<~OUTPUT)
            Removing RBI files of gems that have been removed:

              Nothing to do.
          OUTPUT
          assert_includes(output, <<~OUTPUT)
            Generating RBI files of gems that are added or updated:

              Nothing to do.
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")
        end

        it "generate an empty RBI file" do
          output = tapioca("gem")

          assert_includes(output, "      create  #{outdir}/qux@0.5.0.rbi\n")
          assert_includes(output, <<~OUTPUT)
            Compiling qux, this may take a few seconds...   Done (empty output)
          OUTPUT

          assert_equal(<<~CONTENTS.chomp, File.read("#{outdir}/qux@0.5.0.rbi"))
            # typed: true

            # DO NOT EDIT MANUALLY
            # This is an autogenerated file for types exported from the `qux` gem.
            # Please instead update this file by running `bin/tapioca gem qux`.

            # THIS IS AN EMPTY RBI FILE.
            # see https://github.com/Shopify/tapioca/wiki/Manual-Gem-Requires

          CONTENTS
        end

        it "generate an empty RBI file without header" do
          tapioca("gem --no-file-header")

          assert_equal(<<~CONTENTS.chomp, File.read("#{outdir}/qux@0.5.0.rbi"))
            # typed: true

            # THIS IS AN EMPTY RBI FILE.
            # see https://github.com/Shopify/tapioca/wiki/Manual-Gem-Requires

          CONTENTS
        end

        it "must respect exclude option" do
          tapioca("gem")

          output = tapioca("gem --exclude foo bar")

          assert_includes(output, "-- Removing: #{outdir}/foo@0.0.1.rbi\n")
          assert_includes(output, "-- Removing: #{outdir}/bar@0.3.0.rbi\n")
          refute_includes(output, "-- Removing: #{outdir}/baz@0.0.2.rbi\n")
          refute_includes(output, "      create")
          refute_includes(output, "-> Moving:")

          refute_includes(output, <<~OUTPUT)
            Removing RBI files of gems that have been removed:

              Nothing to do.
          OUTPUT
          assert_includes(output, <<~OUTPUT)
            Generating RBI files of gems that are added or updated:

              Nothing to do.
          OUTPUT

          refute_path_exists("#{outdir}/foo@0.0.1.rbi")
          refute_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")
        end

        it "must remove outdated RBIs" do
          tapioca("gem")
          FileUtils.touch("#{outdir}/outdated@5.0.0.rbi")

          output = tapioca("gem")

          assert_includes(output, "-- Removing: #{outdir}/outdated@5.0.0.rbi\n")
          refute_includes(output, "      create")
          refute_includes(output, "-> Moving:")

          assert_includes(output, <<~OUTPUT)
            Generating RBI files of gems that are added or updated:

              Nothing to do.
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")
          refute_path_exists("#{outdir}/outdated@5.0.0.rbi")
        end

        it "must add missing RBIs" do
          ["foo@0.0.1.rbi"].each do |rbi|
            FileUtils.touch("#{outdir}/#{rbi}")
          end

          output = tapioca("gem")

          assert_includes(output, "      create  #{outdir}/bar@0.3.0.rbi\n")
          assert_includes(output, "      create  #{outdir}/baz@0.0.2.rbi\n")
          refute_includes(output, "-- Removing:")
          refute_includes(output, "-> Moving:")

          assert_includes(output, <<~OUTPUT)
            Removing RBI files of gems that have been removed:

              Nothing to do.
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")
        end

        it "must move outdated RBIs" do
          ["foo@0.0.1.rbi", "bar@0.0.1.rbi", "baz@0.0.1.rbi"].each do |rbi|
            FileUtils.touch("#{outdir}/#{rbi}")
          end

          output = tapioca("gem")

          assert_includes(output, "-> Moving: #{outdir}/bar@0.0.1.rbi to #{outdir}/bar@0.3.0.rbi\n")
          assert_includes(output, "force  #{outdir}/bar@0.3.0.rbi\n")
          assert_includes(output, "-> Moving: #{outdir}/baz@0.0.1.rbi to #{outdir}/baz@0.0.2.rbi\n")
          assert_includes(output, "force  #{outdir}/baz@0.0.2.rbi\n")
          refute_includes(output, "-- Removing:")

          assert_includes(output, <<~OUTPUT)
            Removing RBI files of gems that have been removed:

              Nothing to do.
          OUTPUT

          assert_path_exists("#{outdir}/foo@0.0.1.rbi")
          assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          assert_path_exists("#{outdir}/baz@0.0.2.rbi")

          refute_path_exists("#{outdir}/bar@0.0.1.rbi")
          refute_path_exists("#{outdir}/baz@0.0.1.rbi")
        end
      end

      describe("verify") do
        before do
          tapioca("gem")
        end

        describe("with no changes") do
          it "does nothing and returns exit_status 0" do
            output = tapioca("gem --verify")

            assert_equal(output, <<~OUTPUT)
              Checking for out-of-date RBIs...

              Nothing to do, all RBIs are up-to-date.
            OUTPUT
            assert_includes($?.to_s, "exit 0") # rubocop:disable Style/SpecialGlobalVars
          end
        end

        describe("with excluded files") do
          it "advises of removed file(s) and returns exit_status 1" do
            output = tapioca("gem --verify --exclude foo bar")

            assert_equal(output, <<~OUTPUT)
              Checking for out-of-date RBIs...

              RBI files are out-of-date. In your development environment, please run:
                `bin/tapioca gem`
              Once it is complete, be sure to commit and push any changes

              Reason:
                File(s) removed:
                - #{outdir}/bar@0.3.0.rbi
                - #{outdir}/foo@0.0.1.rbi
            OUTPUT
            assert_includes($?.to_s, "exit 1") # rubocop:disable Style/SpecialGlobalVars

            # Does not actually modify anything
            assert_path_exists("#{outdir}/foo@0.0.1.rbi")
            assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          end
        end

        describe("with added/removed/changed files") do
          before do
            FileUtils.rm("#{outdir}/foo@0.0.1.rbi")
            FileUtils.touch("#{outdir}/outdated@5.0.0.rbi")
            FileUtils.mv("#{outdir}/bar@0.3.0.rbi", "#{outdir}/bar@0.2.0.rbi")
          end

          it "advises of added/removed/changed file(s) and returns exit_status 1" do
            output = tapioca("gem --verify")

            assert_equal(output, <<~OUTPUT)
              Checking for out-of-date RBIs...

              RBI files are out-of-date. In your development environment, please run:
                `bin/tapioca gem`
              Once it is complete, be sure to commit and push any changes

              Reason:
                File(s) added:
                - #{outdir}/foo@0.0.1.rbi
                File(s) changed:
                - #{outdir}/bar@0.3.0.rbi
                File(s) removed:
                - #{outdir}/outdated@5.0.0.rbi
            OUTPUT
            assert_includes($?.to_s, "exit 1") # rubocop:disable Style/SpecialGlobalVars

            # Does not actually modify anything
            refute_path_exists("#{outdir}/foo@0.0.1.rbi")
            assert_path_exists("#{outdir}/outdated@5.0.0.rbi")
            assert_path_exists("#{outdir}/bar@0.2.0.rbi")
          end
        end
      end
    end
  end
end
