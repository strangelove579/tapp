package TAPP::Exception;
{
  $TAPP::Exception::VERSION = '0.001';
}
use strict;
use Exception::Class (
      #my $caller = (caller(0))[3];
    # TAPP::Exception -------------------------------------------------------------------------------------------------------
    'TAPP::Exception' => { description => 'General TAPP Exception list' },
    
    'TAPP::IOException'                => { isa => 'TAPP::Exception', description => '' },
    'TAPP::FileIOException'            => { isa => 'TAPP::Exception', description => '' },
    'TAPP::FileNotFoundException'      => { isa => 'TAPP::Exception', description => '' },
    'TAPP::IllegalArgumentException'   => { isa => 'TAPP::Exception', description => '' },
    'TAPP::DuplicateKeysException'     => { isa => 'TAPP::Exception', description => '' },
    'TAPP::MissingArgumentsException'  => { isa => 'TAPP::Exception', description => '' },
    'TAPP::InvalidDatatypeException'   => { isa => 'TAPP::Exception', description => '' },
    'TAPP::DatatypeConversionError'    => { isa => 'TAPP::Exception', description => '' },
    'TAPP::HashException'              => { isa => 'TAPP::Exception', description => '' },
    'TAPP::Exec::Timeout'              => { isa => 'TAPP::Exception', description => '' },
    'TAPP::Exec::GeneralException'     => { isa => 'TAPP::Exception', description => '' },
    'TAPP::Xr22::Xr22Exception'        => { isa => 'TAPP::Exception', description => '' },
    'TAPP::MaxAttemptsExceeded'        => { isa => 'TAPP::Exception', description => '' },
    'TAPP::IllegalStateException'      => { isa => 'TAPP::Exception', description => '' },
    'TAPP::JSONDecodeException'        => { isa => 'TAPP::Exception', description => '' },
    
    # TAPP::UIM::Exception --------------------------------------------------------------------------------------------------
    'TAPP::UIM::Exception' => { description => '' },
    
    'TAPP::UIM::PUParseException'     => { isa => 'TAPP::UIM::Exception', description => '', fields => [qw/exit_status errorstr/] },
    'TAPP::UIM::HubListException'     => { isa => 'TAPP::UIM::Exception', description => '' },
    'TAPP::UIM::RobotListException'   => { isa => 'TAPP::UIM::Exception', description => '' }, 
    'TAPP::UIM::RobotDetailException' => { isa => 'TAPP::UIM::Exception', description => '' },
    'TAPP::UIM::HubDetailException'   => { isa => 'TAPP::UIM::Exception', description => '' },
    'TAPP::UIM::ProbeListException'   => { isa => 'TAPP::UIM::Exception', description => '' },
    'TAPP::UIM::PackageListException' => { isa => 'TAPP::UIM::Exception', description => '' },
    'TAPP::UIM::PUExecFailed'      => {
                isa         => 'TAPP::UIM::Exception',
                description => '',
                fields      => [qw/name domain hub robotname hubrobotname message command timedout errorstr exit_status/]
            },
    'TAPP::UIM::PUExecTimeout'      => {
                isa         => 'TAPP::UIM::Exception',
                description => '',
                fields      => [qw/name domain hub robotname hubrobotname message command timedout errorstr exit_status/]
            },  
    'TAPP::UIM::PUExecUnhandledException'      => {
                isa         => 'TAPP::UIM::Exception',
                description => '',
                fields      => [qw/name domain hub robotname hubrobotname message command timedout errorstr exit_status/]
            },
    
      
    # TAPP::Config::UNIVERSAL::Exception ------------------------------------------------------------------------------------
    'TAPP::Config::UNIVERSAL::Exception' => { description => '' },
    
    'TAPP::Config::UNIVERSAL::MissingSectionException' => { isa => 'TAPP::Config::UNIVERSAL::Exception', description => '' },
    'TAPP::Config::UNIVERSAL::ConfigParseException'    => { isa => 'TAPP::Config::UNIVERSAL::Exception', description => '' },
    'TAPP::Config::UNIVERSAL::NoSectionException'      => { isa => 'TAPP::Config::UNIVERSAL::Exception', description => '' },
  
    # TAPP::DB::Oracle::Exception -------------------------------------------------------------------------------------------
    'TAPP::DB::Oracle::Exception' => { description => '' },
    
    'TAPP::DB::Oracle::ConnectionException'   => { isa => 'TAPP::DB::Oracle::Exception', description => '' },
    'TAPP::DB::Oracle::InitException'         => { isa => 'TAPP::DB::Oracle::Exception', description => '' },
    'TAPP::DB::Oracle::PingException'         => { isa => 'TAPP::DB::Oracle::Exception', description => '' },
    'TAPP::DB::Oracle::TransactionException'  => { isa => 'TAPP::DB::Oracle::Exception', description => '' },   
    'TAPP::DB::Oracle::SQLException'          => { isa => 'TAPP::DB::Oracle::Exception', description => '', fields => 'sql' },  
    'TAPP::DB::Oracle::PrepareSQLException'   => { isa => 'TAPP::DB::Oracle::Exception', description => '', fields => 'sql' },
    'TAPP::DB::Oracle::RollbackException'     => { isa => 'TAPP::DB::Oracle::Exception', description => '', fields => 'sql' }, 
    
    # TAPP::Job::Manager::Exception -----------------------------------------------------------------------------------------
    'TAPP::Job::Manager::Exception' => { description => '' },
  
    'TAPP::Job::Manager::BadExitException'            => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::StartJobException'           => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::UnfinishedException'         => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::FinishJobException'          => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::SchedulerFinishJobException' => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::HeartbeatException'          => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::DBNotConnectedException'     => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    'TAPP::Job::Manager::StatusCheckException'        => { isa => 'TAPP::Job::Manager::Exception', description => '' },
    
    # TAPP::SQL::Library::Exception -----------------------------------------------------------------------------------------
    'TAPP::SQL::Library::Exception' => { description => '' },
  
  
    'TAPP::SQL::Library::SQLLibStatmentParseException' => { isa => 'TAPP::SQL::Library::Exception', description => '' },
    'TAPP::SQL::Library::SQLPrepareException'          => { isa => 'TAPP::SQL::Library::Exception', description => '' },
    'TAPP::SQL::Library::SQLExecException'             => { isa => 'TAPP::SQL::Library::Exception', description => '' },
    'TAPP::SQL::Library::SQLDBException'               => { isa => 'TAPP::SQL::Library::Exception', description => '' },
    'TAPP::SQL::Library::NoIDDefinedException'         => { isa => 'TAPP::SQL::Library::Exception', description => '' },
    
    # TAPP::WebService::CSM::Exception --------------------------------------------------------------------------------------
    'TAPP::WebService::CSM::Exception' => { description => '' },
    
    'TAPP::WebService::CSM::CreateCiFailedException'   => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::UpdateCiFailedException'   => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::InvalidStateException'     => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::SOAPCallException'         => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::SOMParseException'         => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::NoPayloadException'        => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::HTTPException'             => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::ParseSOMBadReturnStatus'   => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::WSDLDefException'          => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::WSDLSelectException'       => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
    'TAPP::WebService::CSM::AutoloadException'         => { isa => 'TAPP::WebService::CSM::Exception', description => '' },
  );

1;


