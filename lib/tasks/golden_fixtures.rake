namespace :auth do
  desc "Copy the golden token fixtures into a downstream repo: rake auth:golden_fixtures[../noted]"
  task :golden_fixtures, [:dest] => :environment do |_task, args|
    source = Rails.root.join("spec/fixtures/golden.json")
    abort "run `rspec spec/golden_fixtures_spec.rb --tag golden` first" unless source.exist?

    dest = File.join(File.expand_path(args.fetch(:dest)), "spec/fixtures/auth/golden.json")
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(source, dest)

    puts "copied #{source} -> #{dest}"
  end
end
