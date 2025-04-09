const express = require('express');
const mysql = require('mysql2');
const bodyParser = require('body-parser');
const cors = require('cors');
const app = express();
const port = 3000;
app.use(cors());
app.use(bodyParser.json());
app.use(express.json());
const db = mysql.createConnection({
  host: 'localhost',   
  user: 'root',  
  password: '12345678', 
  database: 'driver'   
});

db.connect((err) => {
  if (err) {
    console.error('Database connection failed: ' + err.stack);
    return;
  }
  console.log('Connected to MySQL database');
});

//====================================================================================================
//Register
const bcrypt = require('bcrypt');
app.post('/register', async (req, res) => {
  const { username, password } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);
  
  const checkQuery = 'SELECT * FROM user WHERE username = ?';
  db.query(checkQuery, [username], (err, results) => {
      if (err) {
          return res.status(500).json({ status: 'error', message: 'Error checking username' });
      }

      if (results.length > 0) {
          res.status(400).json({ status: 'error', message: 'Username already exists' });
      } else {
          const insertQuery = 'INSERT INTO user (username, password) VALUES (?, ?)';
          db.query(insertQuery, [username, hashedPassword], (err, result) => {
              if (err) {
                  res.status(500).json({ status: 'error', message: 'Error registering user' });
              } else {
                  res.status(200).json({ status: 'success', message: 'User registered successfully' });
              }
          });
      }
  });
});

  
//====================================================================================================
//Login
app.post('/login', (req, res) => {
  const { username, password } = req.body;
  const query = 'SELECT * FROM user WHERE username = ?';

  db.query(query, [username], async (err, results) => {
    if (err) {
      console.error('Database error:', err);
      return res.status(500).json({ status: 'error', message: 'Server error' });
    }

    if (results.length > 0) {
      const user = results[0];
      console.log('User found:', user);

      // ตรวจสอบการแฮชรหัสผ่าน
      const match = await bcrypt.compare(password, user.password);
      console.log('Password match status:', match);

      if (match) {
        res.status(200).json({
          status: 'success',
          message: 'Login successful',
          data: {
            UserID: user.UserID,
            username: user.username,
            name: user.name || 'N/A',
            email: user.email || 'N/A',
            phone: user.phone || 'N/A'
          },
        });
      } else {
        console.log('Password did not match');
        res.status(401).json({ status: 'error', message: 'Invalid username or password' });
      }
    } else {
      console.log('User not found');
      res.status(401).json({ status: 'error', message: 'Invalid username or password' });
    }
  });
});


//==========================================================================================
//Profile

app.get('/profile', (req, res) => {
  const UserID = req.query.ID; 
 
  if (!UserID) {
    return res.status(400).json({ status: 'error', message: 'User ID is required' });
  }

  const query = 'SELECT * FROM user WHERE UserID = ?'; 
  db.query(query, [UserID], (err, results) => {
    try{
    if (err) {
      return res.status(500).json({ status: 'error', message: 'Database query error' });
    }
    console.log('Query results:', results);
    if (results.length > 0) {
      res.status(200).json({ status: 'success', data: results[0] });
    } 
    else {
      
      res.status(404).json({ status: 'error', message: 'User not found' });
    }}

    catch{
      res.status(500).json({ status: 'error', message: error.message });
    }
  });
});

//Edit=======================================================================================

app.put('/profile_edit/:UserId', (req, res) => {

  const UserId = req.params.UserId;
  const { name, email, phone } = req.body; 

  if (phone === undefined) {
    return res.status(400).json({ status: 'error', message: 'Phone number is required' });
  }

  const query = `
    UPDATE user
    SET name = ?, email = ?, phone = ?
    WHERE UserID = ?`;

  db.query(query, [name, email, phone, UserId], (err, results) => {
    if (err) {
      res.status(500).json({ status: 'error', message: 'Error updating profile' });
    } else {
      res.status(200).json({ status: 'success', message: 'Profile updated successfully' });
    }
  });
});

//Edit=======================================================================================

app.post('/notifications', (req, res) => {
  const { date, time, cause, userId } = req.body;

  if (!date || !time || !cause || !userId) {
    return res.status(400).send('All fields are required');
  }

  const query = `INSERT INTO notification (date, time, cause, UserID) VALUES (?, ?, ?, ?)`;
  db.query(query, [date, time, cause, userId], (err, results) => {
    if (err) {
      console.error('Error inserting notification:', err);
      return res.status(500).send('Error inserting notification');
    }
    res.status(201).send('Notification added successfully');
  });
});

//history=======================================================================================

app.get('/history', (req, res) => {
  const userId = req.query.userId;
  console.log('ได้รับคำขอการแจ้งเตือนสำหรับ userId:', userId);

  if (!userId) {
    return res.status(400).json({ error: 'ต้องระบุ userId' });
  }

  const query = `SELECT * FROM notification WHERE UserID = ?`;
  db.query(query, [userId], (err, results) => {
    if (err) {
      console.error('Error fetching notifications:', err);
      return res.status(500).send('Error fetching notifications');
    }
    res.json(results);
  });
});
//================================================================================================

app.post('/start', (req, res) => {
  const { userId ,starttime} = req.body;

  if (!userId || !starttime) {
    return res.status(400).send('Missing starttime or userId');
  }

  const query = `INSERT INTO time ( UserID,starttime) VALUES (?, ?)`;
  db.query(query, [ userId,starttime], (err, results) => {
    if (err) {
      console.error('Error :', err);
      return res.status(500).send('Error');
    }
    res.status(201).send('Start time added successfully');
  });
});

app.post('/stop', (req, res) => {
  const { userId, stoptime } = req.body;

  const query = `UPDATE time SET stoptime = ? 
                 WHERE UserID = ? AND stoptime IS NULL 
                 ORDER BY TimeID DESC LIMIT 1`;

  db.query(query, [stoptime, userId], (err, results) => {
    if (err) {
      console.error('Error :', err);
      return res.status(500).send('Error updating stop time');
    }
    res.status(200).send('Stop time updated successfully');
  });
});

//===================================================================================================

app.get('/usertime', (req, res) => {
  const userId = req.query.userId;

  if (!userId) {
    return res.status(400).json({ status: 'error', message: 'ต้องระบุ userId' });
  }

  const query = `SELECT TimeID, starttime, stoptime FROM time WHERE UserID = ? ORDER BY TimeID DESC`;

  db.query(query, [userId], (err, results) => {
    if (err) {
      console.error('Error fetching user time history:', err);
      return res.status(500).json({ status: 'error', message: 'ดึงข้อมูลไม่สำเร็จ' });
    }

    res.status(200).json({
      status: 'success',
      data: results
    });
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${port}`);
});