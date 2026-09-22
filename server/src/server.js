const express = require('express');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    project: 'Sigilborne API'
  });
});

const PORT = 3000;

app.listen(PORT, () => {
  console.log(`Sigilborne API rodando na porta ${PORT}`);
});