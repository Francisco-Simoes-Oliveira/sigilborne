const express = require('express');
const cors = require('cors');



const userRoutes = require('./routes/user.routes');
const characterRoutes =
    require('./routes/character.routes');
const classRoutes =
    require('./routes/class.routes');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    project: 'Sigilborne API',
  });
});

app.use('/api', userRoutes);
app.use('/api', characterRoutes);
app.use('/api', classRoutes);

const PORT = 3000;

app.listen(PORT, () => {
  console.log(
    `Sigilborne API rodando em http://localhost:${PORT}`
  );
});