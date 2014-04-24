class MoveContratosParaTimeEntriesCorreto < ActiveRecord::Migration
  def up
    logger = Logger.new("migration_timentries")
    jonatas_android = 66
    jonatas_web = 113
    jonatas_3d = 115
    pats_web =  58
    pats_3d = 57
    TimeEntry.where(contract_id: jonatas_android).each do |entry|
      if entry.comments =~ /site|cms|refinery|wmitrut/
        logger.info "migrando para contract_id #{jonatas_web} >> ##{entry.id}: #{entry.hours} - #{entry.comments}"
        entry.contract_id = jonatas_web
        entry.project_id = pats_web
        entry.save
      elsif entry.comments =~ /3D/
        logger.info "migrando para contract_id #{jonatas_3d} >> ##{entry.id}: #{entry.hours} - #{entry.comments}"
        entry.contract_id = jonatas_3d
        entry.project_id = pats_3d
        entry.save
      end
    end
  end


  def down
  end
end
