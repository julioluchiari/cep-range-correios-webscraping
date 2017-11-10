require 'faraday'
require 'nokogiri'
require 'json'

url = 'http://www.buscacep.correios.com.br/sistemas/buscacep/ResultadoBuscaFaixaCEP.cfm'

faraday = Faraday.new(url: url)

form_data = {
  Localidade: '**',
  Bairro: '',
  qtdrow: 100
}

ufs = %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA
         PB PE PI PR RJ RN RO RR RS SC SE SP TO]

zipcode_hash = {}

content_type = 'application/x-www-form-urlencoded; charset=utf-8'

ufs.each do |uf|
  range_array = []

  (1..800).step(100) do |index|
    form_data[:UF] = uf
    form_data[:pagini] = index
    form_data[:pagfim] = index + 100

    response = faraday.post do |req|
      req.body = form_data
      req.headers['Content-Type'] = content_type
    end

    selector = 'body > div.back > div.tabs > div:nth-child(2) > div > div > div.column2 > div.content > div.ctrlcontent > table'

    selector += ':nth-child(9)' if index == 1

    page = Nokogiri::HTML(response.body)
    rows = page.css("#{selector} > tr:nth-child(n+3)")
    rows.each do |r|
      values = []
      cells = r.css('td')
      cells.each_with_index do |c, i|
        if i == 1
          splited = c.text.split('a')
          values.push splited[0].strip.delete('-')
          values.push splited[1].strip.delete('-')
        else
          values.push c.text.strip
        end
      end

      range_array.push(locale: values[0],
                       from: values[1],
                       to: values[2],
                       situation: values[3],
                       zipcode_type: values[4])
    end
  end

  zipcode_hash[uf] = range_array

  File.open('zipcode_range.json', 'w') do |f|
    f.write(JSON.pretty_generate(zipcode_hash))
  end
end
