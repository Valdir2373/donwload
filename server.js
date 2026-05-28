const express = require('express')
const multer = require('multer')
const path = require('path')
const fs = require('fs')

// Configurar multer para preservar nome original
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/')
  },
  filename: (req, file, cb) => {
    // Preservar o nome original do arquivo
    cb(null, file.originalname)
  }
})

const upload = multer({ storage: storage })

const app = express()
app.use(express.static('public'))

app.post('/profile', upload.single("file"), function (req, res, next) {
    //abaixar o arquivo para a pasta uploads
    res.json({ message: 'Arquivo enviado com sucesso', file: req.file })
})

app.post('/photos/upload', upload.array('photos', 12), function (req, res, next) {
  // req.files é um array de arquivos `photos`
  // req.body conterá os campos de texto, se houver
  res.json({ message: 'Arquivos enviados com sucesso', files: req.files })
})

const uploadMiddleware = upload.fields([{ name: 'avatar', maxCount: 1 }, { name: 'gallery', maxCount: 8 }])
app.post('/cool-profile', uploadMiddleware, function (req, res, next) {
  // req.files é um objeto (String -> Array) onde fieldname é a chave e o valor é array de arquivos
  //
  // e.g.
  //  req.files['avatar'][0] -> File
  //  req.files['gallery'] -> Array
  //
  // req.body conterá os campos de texto, se houver
  res.json({ message: 'Perfil atualizado com sucesso' })
})

// Rota para listar arquivos disponíveis para download
app.get('/files', (req, res) => {
  fs.readdir('uploads/', (err, files) => {
    if (err) {
      return res.status(500).json({ error: 'Erro ao ler pasta' })
    }
    res.json({ files: files })
  })
})

// Rota para download de arquivo com streaming (funciona com qualquer tamanho)
app.get('/download/:filename', (req, res) => {
  const filename = req.params.filename
  const filepath = path.join('uploads/', filename)

  // Segurança: evitar path traversal


  // Verificar se arquivo existe
  fs.access(filepath, fs.constants.F_OK, (err) => {
    if (err) {
      return res.status(404).json({ error: 'Arquivo não encontrado' })
    }

    // Fazer download com streaming
    res.download(filepath, filename, (err) => {
      if (err) {
        console.error('Erro ao fazer download:', err)
      }
    })
  })
})

app.listen(3000, () => {
  console.log('Server is running on port 3000')
})