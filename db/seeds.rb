arl = ActiveRecord::Base.logger.level
ActiveRecord::Base.logger.level = Logger::INFO

#######################  USUARIOS

unless Nimbus::Config[:excluir_usuarios]
  if Usuario.count == 0
    puts 'Usuarios'

    HUsuario.delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!('usuarios')
    ActiveRecord::Base.connection.reset_pk_sequence!('h_usuarios')

    Usuario.create({
      codigo: 'admin',
      nombre: 'Administrador',
      admin: true,
      password_salt: '$2a$10$nE9JPk2VedGY40K2MWlJ2u',
      password_hash: '$2a$10$nE9JPk2VedGY40K2MWlJ2u7tPTIk1olvKDsh.b4L4spcLZXVj9vIe',
      password_fec_mod: Nimbus.now,
      pref: {}
    })
  end
end

#######################  DIVISAS

unless Nimbus::Config[:excluir_divisas]
  puts 'Divisas'

  divisas = [
    ['EUR', 'Euro', 2, nil, '€'],
    ['USD', 'Dólar estadounidense', 2, '$'],
    ['CAD', 'Dólar canadiense', 2],
    ['GBP', 'Libra esterlina', 2],
    ['GIP', 'Libra de Gibraltar', 2],
    ['CNY', 'Yuan chino', 2],
    ['JPY', 'Yen', 0],
    ['RUB', 'Rublo', 2],
    ['MAD', 'Dírham marroquí', 2],
    ['DKK', 'Corona danesa', 2],
    ['SEK', 'Corona sueca', 2],
    ['NOK', 'Corona noruega', 2],
    ['MXN', 'Peso mexicano', 2],
    ['BRL', 'Real brasileño', 2],
    ['ARS', 'Peso argentino', 3],
    ['AUD', 'Dólar australiano', 2],
    ['BOB', 'Boliviano', 2],
    ['CLP', 'Peso chileno', 0],
    ['COP', 'Peso colombiano', 2],
    ['CUP', 'Peso cubano', 2],
    ['CRC', 'Colón costarricense', 2],
    ['CZK', 'Corona checa', 2],
    ['GTQ', 'Quetzal', 2],
    ['HNL', 'Lempira', 2],
    ['HUF', 'Forinto', 2],
    ['HRK', 'Kuna', 2],
    ['ISK', 'Corona islandesa', 0],
    ['NIO', 'Córdoba', 2],
    ['PEN', 'Sol', 2],
    ['PLN', 'Zloty', 2],
    ['PYG', 'Guaraní', 0],
    ['RON', 'Leu rumano', 2],
    ['RSD', 'Dinar serbio', 2],
    ['TRY', 'Lira turca', 2],
    ['UYU', 'Peso uruguayo', 2],
    ['VES', 'Bolívar soberano', 2],
  ]
  divisas.each {|d|
    Divisa.create(codigo: d[0], descripcion: d[1], decimales: d[2], prefijo: d[3], sufijo: d[4], user_id: 1) rescue nil
  }
end

#######################  PAISES

unless Nimbus::Config[:excluir_paises]
  puts 'Países'

  paises = [
    ['Afganistán','AF','AFG','004'],
    ['Åland, Islas','AX','ALA','248', 'EUR'],
    ['Albania','AL','ALB','008'],
    ['Alemania','DE','DEU','276', 'EUR'],
    ['Andorra','AD','AND','020', 'EUR'],
    ['Angola','AO','AGO','024'],
    ['Anguila','AI','AIA','660'],
    ['Antártida','AQ','ATA','010'],
    ['Antigua y Barbuda','AG','ATG','028'],
    ['Arabia Saudita','SA','SAU','682'],
    ['Argelia','DZ','DZA','012'],
    ['Argentina','AR','ARG','032', 'ARS'],
    ['Armenia','AM','ARM','051'],
    ['Aruba','AW','ABW','533'],
    ['Australia','AU','AUS','036', 'AUD'],
    ['Austria','AT','AUT','040', 'EUR'],
    ['Azerbaiyán','AZ','AZE','031'],
    ['Bahamas','BS','BHS','044'],
    ['Bangladesh','BD','BGD','050'],
    ['Barbados','BB','BRB','052'],
    ['Bahrein','BH','BHR','048'],
    ['Bélgica','BE','BEL','056', 'EUR'],
    ['Belice','BZ','BLZ','084'],
    ['Benin','BJ','BEN','204'],
    ['Bermudas','BM','BMU','060'],
    ['Belarús','BY','BLR','112'],
    ['Bolivia (Estado Plurinacional de)','BO','BOL','068', 'BOB'],
    ['Bonaire, San Eustaquio y Saba','BQ','BES','535'],
    ['Bosnia y Herzegovina','BA','BIH','070'],
    ['Botswana','BW','BWA','072'],
    ['Brasil','BR','BRA','076', 'BRL'],
    ['Brunei Darussalam','BN','BRN','096'],
    ['Bulgaria','BG','BGR','100'],
    ['Burkina Faso','BF','BFA','854'],
    ['Burundi','BI','BDI','108'],
    ['Bhután','BT','BTN','064'],
    ['Cabo Verde','CV','CPV','132'],
    ['Camboya','KH','KHM','116'],
    ['Camerún','CM','CMR','120'],
    ['Canadá','CA','CAN','124', 'CAD'],
    ['Qatar','QA','QAT','634'],
    ['Chad','TD','TCD','148'],
    ['Chile','CL','CHL','152', 'CLP'],
    ['China','CN','CHN','156', 'CNY'],
    ['Chipre','CY','CYP','196', 'EUR'],
    ['Colombia','CO','COL','170', 'COP'],
    ['Comoras (las)','KM','COM','174'],
    ['Corea (República Popular Democrática de)','KP','PRK','408'],
    ['Corea (República de)','KR','KOR','410'],
    ['Costa de Marfil','CI','CIV','384'],
    ['Costa Rica','CR','CRI','188', 'CRC'],
    ['Croacia','HR','HRV','191', 'HRK'],
    ['Cuba','CU','CUB','192', 'CUP'],
    ['Curaçao','CW','CUW','531'],
    ['Dinamarca','DK','DNK','208', 'DKK'],
    ['Dominica','DM','DMA','212'],
    ['Ecuador','EC','ECU','218', 'USD'],
    ['Egipto','EG','EGY','818'],
    ['El Salvador','SV','SLV','222', 'USD'],
    ['Emiratos Árabes Unidos','AE','ARE','784'],
    ['Eritrea','ER','ERI','232'],
    ['Eslovaquia','SK','SVK','703', 'EUR'],
    ['Eslovenia','SI','SVN','705', 'EUR'],
    ['España','ES','ESP','724', 'EUR'],
    ['Estados Unidos de América','US','USA','840', 'USD'],
    ['Estonia','EE','EST','233', 'EUR'],
    ['Etiopía','ET','ETH','231'],
    ['Filipinas','PH','PHL','608'],
    ['Finlandia','FI','FIN','246', 'EUR'],
    ['Fiji','FJ','FJI','242'],
    ['Francia','FR','FRA','250', 'EUR'],
    ['Gabón','GA','GAB','266'],
    ['Gambia','GM','GMB','270'],
    ['Georgia','GE','GEO','268'],
    ['Ghana','GH','GHA','288'],
    ['Gibraltar','GI','GIB','292', 'GIP'],
    ['Granada','GD','GRD','308'],
    ['Grecia','GR','GRC','300', 'EUR'],
    ['Groenlandia','GL','GRL','304', 'DKK'],
    ['Guadeloupe','GP','GLP','312', 'EUR'],
    ['Guam','GU','GUM','316', 'USD'],
    ['Guatemala','GT','GTM','320', 'GTQ'],
    ['Guayana Francesa','GF','GUF','254', 'EUR'],
    ['Guernsey','GG','GGY','831', 'GBP'],
    ['Guinea','GN','GIN','324'],
    ['Guinea Bissau','GW','GNB','624'],
    ['Guinea Ecuatorial','GQ','GNQ','226'],
    ['Guyana','GY','GUY','328'],
    ['Haití','HT','HTI','332', 'USD'],
    ['Honduras','HN','HND','340', 'HNL'],
    ['Hong Kong','HK','HKG','344'],
    ['Hungría','HU','HUN','348', 'HUF'],
    ['India','IN','IND','356'],
    ['Indonesia','ID','IDN','360'],
    ['Iraq','IQ','IRQ','368'],
    ['Irán (República Islámica de)','IR','IRN','364'],
    ['Irlanda','IE','IRL','372', 'EUR'],
    ['Bouvet, Isla','BV','BVT','074'],
    ['Isla de Man','IM','IMN','833', 'GBP'],
    ['Navidad, Isla de','CX','CXR','162', 'AUD'],
    ['Islandia','IS','ISL','352', 'ISK'],
    ['Caimán, Islas','KY','CYM','136'],
    ['Cocos / Keeling, Islas','CC','CCK','166', 'AUD'],
    ['Cook, Islas','CK','COK','184'],
    ['Feroe, Islas','FO','FRO','234', 'DKK'],
    ['Georgia del Sur y las Islas Sandwich del Sur','GS','SGS','239'],
    ['Heard (Isla) e Islas McDonald','HM','HMD','334', 'AUD'],
    ['Malvinas [Falkland], Islas','FK','FLK','238'],
    ['Marianas del Norte, Islas','MP','MNP','580', 'USD'],
    ['Marshall, Islas','MH','MHL','584', 'USD'],
    ['Pitcairn','PN','PCN','612'],
    ['Salomón, Islas','SB','SLB','090'],
    ['Turcas y Caicos, Islas','TC','TCA','796'],
    ['Islas Ultramarinas Menores de los Estados Unidos','UM','UMI','581'],
    ['Vírgenes británicas, Islas','VG','VGB','092', 'USD'],
    ['Vírgenes de los Estados Unidos, Islas','VI','VIR','850', 'USD'],
    ['Israel','IL','ISR','376'],
    ['Italia','IT','ITA','380', 'EUR'],
    ['Jamaica','JM','JAM','388'],
    ['Japón','JP','JPN','392', 'JPY'],
    ['Jersey','JE','JEY','832', 'GBP'],
    ['Jordania','JO','JOR','400'],
    ['Kazajstán','KZ','KAZ','398'],
    ['Kenya','KE','KEN','404'],
    ['Kirguistán','KG','KGZ','417'],
    ['Kiribati','KI','KIR','296', 'AUD'],
    ['Kuwait','KW','KWT','414'],
    ['Laos, República Democrática Popular','LA','LAO','418'],
    ['Lesotho','LS','LSO','426'],
    ['Letonia','LV','LVA','428', 'EUR'],
    ['Líbano','LB','LBN','422'],
    ['Liberia','LR','LBR','430'],
    ['Libia','LY','LBY','434'],
    ['Liechtenstein','LI','LIE','438'],
    ['Lituania','LT','LTU','440', 'EUR'],
    ['Luxemburgo','LU','LUX','442', 'EUR'],
    ['Macao','MO','MAC','446'],
    ['Macedonia','MK','MKD','807'],
    ['Madagascar','MG','MDG','450'],
    ['Malasia','MY','MYS','458'],
    ['Malawi','MW','MWI','454'],
    ['Maldivas','MV','MDV','462'],
    ['Malí','ML','MLI','466'],
    ['Malta','MT','MLT','470', 'EUR'],
    ['Marruecos','MA','MAR','504', 'MAD'],
    ['Martinique','MQ','MTQ','474', 'EUR'],
    ['Mauricio','MU','MUS','480'],
    ['Mauritania','MR','MRT','478'],
    ['Mayotte','YT','MYT','175', 'EUR'],
    ['México','MX','MEX','484', 'MXN'],
    ['Micronesia (Estados Federados de)','FM','FSM','583', 'USD'],
    ['Moldova (República de)','MD','MDA','498'],
    ['Mónaco','MC','MCO','492', 'EUR'],
    ['Mongolia','MN','MNG','496'],
    ['Montenegro','ME','MNE','499', 'EUR'],
    ['Montserrat','MS','MSR','500'],
    ['Mozambique','MZ','MOZ','508'],
    ['Myanmar','MM','MMR','104'],
    ['Namibia','NA','NAM','516'],
    ['Nauru','NR','NRU','520', 'AUD'],
    ['Nepal','NP','NPL','524'],
    ['Nicaragua','NI','NIC','558', 'NIO'],
    ['Níger','NE','NER','562'],
    ['Nigeria','NG','NGA','566'],
    ['Niue','NU','NIU','570'],
    ['Norfolk, Isla','NF','NFK','574', 'AUD'],
    ['Noruega','NO','NOR','578', 'NOK'],
    ['Nueva Caledonia','NC','NCL','540'],
    ['Nueva Zelandia','NZ','NZL','554'],
    ['Omán','OM','OMN','512'],
    ['Países Bajos','NL','NLD','528', 'EUR'],
    ['Pakistán','PK','PAK','586'],
    ['Palau','PW','PLW','585'],
    ['Palestina, Estado de','PS','PSE','275'],
    ['Panamá','PA','PAN','591', 'USD'],
    ['Papua Nueva Guinea','PG','PNG','598'],
    ['Paraguay','PY','PRY','600', 'PYG'],
    ['Perú','PE','PER','604', 'PEN'],
    ['Polinesia Francesa','PF','PYF','258'],
    ['Polonia','PL','POL','616', 'PLN'],
    ['Portugal','PT','PRT','620', 'EUR'],
    ['Puerto Rico','PR','PRI','630', 'USD'],
    ['Reino Unido de Gran Bretaña e Irlanda del Norte','GB','GBR','826', 'GBP'],
    ['Sahara Occidental','EH','ESH','732'],
    ['República Centroafricana (la)','CF','CAF','140'],
    ['Chequia','CZ','CZE','203', 'CZK'],
    ['Congo','CG','COG','178'],
    ['Congo (República Democrática del)','CD','COD','180'],
    ['Dominicana, República','DO','DOM','214'],
    ['Reunión','RE','REU','638', 'EUR'],
    ['Rwanda','RW','RWA','646'],
    ['Rumania','RO','ROU','642', 'RON'],
    ['Rusia','RU','RUS','643', 'RUB'],
    ['Samoa','WS','WSM','882'],
    ['Samoa Americana','AS','ASM','016', 'USD'],
    ['Saint Barthélemy','BL','BLM','652', 'EUR'],
    ['Saint Kitts y Nevis','KN','KNA','659'],
    ['San Marino','SM','SMR','674', 'EUR'],
    ['Saint Martin (parte francesa)','MF','MAF','663', 'EUR'],
    ['San Pedro y Miquelón','PM','SPM','666', 'EUR'],
    ['San Vicente y las Granadinas','VC','VCT','670'],
    ['Santa Helena, Ascensión y Tristán de Acuña','SH','SHN','654'],
    ['Santa Lucía','LC','LCA','662'],
    ['Santo Tomé y Príncipe','ST','STP','678'],
    ['Senegal','SN','SEN','686'],
    ['Serbia','RS','SRB','688', 'RSD'],
    ['Seychelles','SC','SYC','690'],
    ['Sierra leona','SL','SLE','694'],
    ['Singapur','SG','SGP','702'],
    ['Sint Maarten (parte neerlandesa)','SX','SXM','534'],
    ['República Árabe Siria','SY','SYR','760'],
    ['Somalia','SO','SOM','706'],
    ['Sri Lanka','LK','LKA','144'],
    ['Swazilandia','SZ','SWZ','748'],
    ['Sudáfrica','ZA','ZAF','710'],
    ['Sudán','SD','SDN','729'],
    ['Sudán del Sur','SS','SSD','728'],
    ['Suecia','SE','SWE','752', 'SEK'],
    ['Suiza','CH','CHE','756'],
    ['Suriname','SR','SUR','740'],
    ['Svalbard y Jan Mayen','SJ','SJM','744'],
    ['Tailandia','TH','THA','764'],
    ['Taiwán (Provincia de China)','TW','TWN','158'],
    ['Tanzania, República Unida de','TZ','TZA','834'],
    ['Tayikistán','TJ','TJK','762'],
    ['Territorio Británico del Océano Índico','IO','IOT','086'],
    ['Tierras Australes Francesas','TF','ATF','260', 'EUR'],
    ['Timor-Leste','TL','TLS','626'],
    ['Togo','TG','TGO','768'],
    ['Tokelau','TK','TKL','772'],
    ['Tonga','TO','TON','776'],
    ['Trinidad y Tabago','TT','TTO','780'],
    ['Túnez','TN','TUN','788'],
    ['Turkmenistán','TM','TKM','795'],
    ['Turquía','TR','TUR','792', 'TRY'],
    ['Tuvalu','TV','TUV','798', 'AUD'],
    ['Ucrania','UA','UKR','804'],
    ['Uganda','UG','UGA','800'],
    ['Uruguay','UY','URY','858', 'UYU'],
    ['Uzbekistán','UZ','UZB','860'],
    ['Vanuatu','VU','VUT','548'],
    ['Vaticano','VA','VAT','336', 'EUR'],
    ['Venezuela (República Bolivariana de)','VE','VEN','862', 'VES'],
    ['Viet Nam','VN','VNM','704'],
    ['Wallis y Futuna','WF','WLF','876'],
    ['Yemen','YE','YEM','887'],
    ['Djibouti','DJ','DJI','262'],
    ['Zambia','ZM','ZMB','894'],
    ['Zimbabwe','ZW','ZWE','716']
  ]

  paises_cee = %w(DE HU AT IE BE IT BG LV CY LT HR LU DK MT SK NL SI PL ES PT EE GB FI CZ FR RO GR SE)

  Pais.transaction {
    paises.each {|p|
      cod = p[1]
      fp = Pais.find_by codigo: cod
      fp = Pais.new unless fp

      fp.codigo = cod
      fp.nombre = p[0] unless fp.nombre.present?
      fp.codigo_iso3 = p[2]
      fp.codigo_num = p[3]
      fp.divisa_id ||= Divisa.where(codigo: p[4]).pluck(:id)[0] if p[4]
      if cod == 'ES'
        fp.tipo = 'N'
      elsif paises_cee.include?(cod)
        fp.tipo = 'C'
      else
        fp.tipo = 'R'
      end
      fp.user_id = 1

      fp.save
    }
  }
end

# Cargar seeds del resto de módulos
Nimbus::ModulosCli.each {|m|
  s = Nimbus::Home + '/' + m + '/db/seeds.rb'
  require(s) if File.exist?(s)
}

ActiveRecord::Base.logger.level = arl
