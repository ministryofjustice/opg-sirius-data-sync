title 'Files copied'

control 'Database Sync' do
  impact 1
  title 'Data Sync Scripts'
  desc 'All data sync scripts should exist in image'
  describe file('/app/backup-environment-to-s3.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/common.sh') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/common-multi-az.sh') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/copy-shared-snapshot.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/create-es-snapshot-repo.py') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/create-es-snapshot-repo.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/create-es-snapshot.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/create-remote-snapshot.py') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/create-shared-snapshot.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/restore-database-cluster-from-snapshot.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/restore-database-methods.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/restore-environment-from-s3.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/restore-es-snapshot.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/restore-global-cluster-from-snapshot.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/upgrade-database-cluster.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/documents.py') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/create_role.sql') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/create-roles.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/database-tuning.sh') do
    it { should exist }
    its('mode') { should cmp '0755'}
  end
  describe file('/app/operator.sql') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/search-app.sql') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/sirius-app.sql') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
  describe file('/app/supervision-finance-app.sql') do
    it { should exist }
    its('mode') { should cmp '0644'}
  end
end

control 'AWS CLI' do
  impact 1
  title 'AWS CLI'
  desc 'AWS CLI'
  describe command('/usr/bin/aws').exist? do
    it { should eq true }
  end
  describe command('aws --version') do
    its('exit_status') { should match 0 }
  end
end

control 'cURL' do
  impact 1
  title 'cURL'
  desc 'Check cURL is installed'
  describe command('/usr/bin/curl').exist? do
    it { should eq true }
  end
  describe command('curl --version') do
    its('exit_status') { should match 0 }
  end
end

control 'jq' do
  impact 1
  title 'jq'
  desc 'Check jq is installed'
  describe command('/usr/bin/jq').exist? do
    it { should eq true }
  end
  describe command('/usr/bin/jq --version') do
    its('exit_status') { should match 0 }
  end
end

control 'pg_dump' do
  impact 1
  title 'pg_dump'
  desc 'Check pg_dump is installed'
  describe command('/usr/bin/pg_dump').exist? do
    it { should eq true }
  end
  describe command('/usr/bin/pg_dump --version') do
    its('exit_status') { should match 0 }
  end
end

control 'Python Dependencies' do
  impact 1
  title 'Python Dependencies'
  desc 'Check python dependencies are installed'
  describe command('python3 --version') do
    its('exit_status') { should match 0 }
  end
  describe command('pip3 list | grep boto3') do
    its('exit_status') { should match 0 }
  end
  describe command('pip3 list | grep "psycopg2           2"') do
    its('exit_status') { should match 0 }
  end
  describe command('pip3 list | grep "requests           2"') do
    its('exit_status') { should match 0 }
  end
  describe command('pip3 list | grep requests-aws4auth') do
    its('exit_status') { should match 0 }
  end
  describe command('python3 -c "import psycopg2"') do
    its('exit_status') { should match 0 }
  end
end
