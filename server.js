require('dotenv').config()
const express = require('express')
const multer = require('multer')
const path = require('path')
const fs = require('fs')
const QRCode = require('qrcode')


const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/')
  },
  filename: (req, file, cb) => {

    cb(null, file.originalname)
  }
})

const upload = multer({ storage: storage })

const app = express()
app.use(express.static('public'))

app.post('/profile', upload.single("file"), function (req, res, next) {

  res.json({ message: 'Arquivo enviado com sucesso', file: req.file })
})

app.post('/photos/upload', upload.array('photos', 12), function (req, res, next) {


  res.json({ message: 'Arquivos enviados com sucesso', files: req.files })
})

const uploadMiddleware = upload.fields([{ name: 'avatar', maxCount: 1 }, { name: 'gallery', maxCount: 8 }])
app.post('/cool-profile', uploadMiddleware, function (req, res, next) {







  res.json({ message: 'Perfil atualizado com sucesso' })
})


app.get('/files', (req, res) => {
  fs.readdir('uploads/', (err, files) => {
    if (err) {
      return res.status(500).json({ error: 'Erro ao ler pasta' })
    }
    res.json({ files: files })
  })
})


app.get('/download/:filename', (req, res) => {
  const filename = req.params.filename
  const filepath = path.join('uploads/', filename)





  fs.access(filepath, fs.constants.F_OK, (err) => {
    if (err) {
      return res.status(404).json({ error: 'Arquivo não encontrado' })
    }


    res.download(filepath, filename, (err) => {
      if (err) {
        console.error('Erro ao fazer download:', err)
      }
    })
  })
})

// Função auxiliar para gerar payload Pix padrão EMV Co com base na chave Pix
function buildPixPayload(key, name = 'VALDIR', city = 'SAO PAULO', amount = 0, txid = '***') {
  const formatField = (tag, val) => {
    const len = String(val).length.toString().padStart(2, '0')
    return `${tag}${len}${val}`
  }

  // Tag 26: Merchant Account Information
  const gui = formatField('00', 'br.gov.bcb.pix')
  const keyField = formatField('01', key)
  const merchantAccount = formatField('26', `${gui}${keyField}`)

  // Tag 52: Merchant Category Code (0000)
  const mcc = formatField('52', '0000')
  // Tag 53: Currency (986 = BRL)
  const currency = formatField('53', '986')
  // Tag 54: Amount
  const amountStr = amount > 0 ? amount.toFixed(2) : ''
  const amountField = amountStr ? formatField('54', amountStr) : ''
  // Tag 58: Country Code
  const country = formatField('58', 'BR')
  // Tag 59: Merchant Name
  const cleanedName = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase().substring(0, 25)
  const merchantName = formatField('59', cleanedName)
  // Tag 60: Merchant City
  const cleanedCity = city.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase().substring(0, 15)
  const merchantCity = formatField('60', cleanedCity)
  // Tag 62: Additional Data (TXID)
  const cleanedTxid = txid.normalize("NFD").replace(/[^a-zA-Z0-9]/g, "").substring(0, 25) || '***'
  const additionalData = formatField('62', formatField('05', cleanedTxid))

  // Build payload except CRC
  let payload = `000201${merchantAccount}${mcc}${currency}${amountField}${country}${merchantName}${merchantCity}${additionalData}6304`

  // Calculate CRC16 CCITT
  let crc = 0xFFFF
  for (let i = 0; i < payload.length; i++) {
    const charCode = payload.charCodeAt(i)
    crc ^= (charCode << 8)
    for (let j = 0; j < 8; j++) {
      if ((crc & 0x8000) !== 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF
      } else {
        crc = (crc << 1) & 0xFFFF
      }
    }
  }
  const crcHex = crc.toString(16).toUpperCase().padStart(4, '0')
  return `${payload}${crcHex}`
}

// Endpoint /qrCode (GET) para servir a imagem do QR Code
app.get('/qrCode', async (req, res) => {
  try {
    let payload = process.env.PIX_PAYLOAD

    // Se não tiver o payload completo, gera dinamicamente com base na chave Pix
    if (!payload && process.env.PIX_KEY) {
      payload = buildPixPayload(
        process.env.PIX_KEY,
        process.env.PIX_NAME || 'VALDIR SILVA',
        process.env.PIX_CITY || 'SAO PAULO'
      )
    }

    // Caso nada esteja configurado no .env, retorna erro
    if (!payload) {
      return res.status(500).send('Erro: Configure PIX_PAYLOAD ou PIX_KEY no arquivo .env')
    }

    // Gera o QR Code em buffer PNG
    const qrBuffer = await QRCode.toBuffer(payload, {
      type: 'png',
      width: 400,
      margin: 2
    })

    res.setHeader('Content-Type', 'image/png')
    return res.send(qrBuffer)
  } catch (err) {
    console.error('Erro ao gerar imagem do QR Code:', err)
    return res.status(500).send('Erro interno ao gerar a imagem do QR Code')
  }
})

const PORT = process.env.PORT || 3000
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`)
})