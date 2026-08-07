// /api/create-payment.js
// Vercel serverless function — processes Square guest giving payments
// Env vars required: SQUARE_ACCESS_TOKEN, SQUARE_LOCATION_ID

const { randomUUID } = require('crypto');

module.exports = async function handler(req, res) {
  // CORS headers (same domain, but belt-and-suspenders)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { sourceId, amount, coverFees, note } = req.body;

  // Validate
  if (!sourceId || typeof sourceId !== 'string') {
    return res.status(400).json({ error: 'Missing payment source.' });
  }
  if (!amount || isNaN(amount) || amount <= 0) {
    return res.status(400).json({ error: 'Invalid amount.' });
  }

  // Calculate final amount in cents
  // If donor covers fees: gross up so church nets the full intended gift
  // Formula: (intended + 0.30) / (1 - 0.029)
  let amountCents;
  if (coverFees) {
    amountCents = Math.round(((parseFloat(amount) + 0.30) / (1 - 0.029)) * 100);
  } else {
    amountCents = Math.round(parseFloat(amount) * 100);
  }

  const idempotencyKey = randomUUID();

  try {
    const response = await fetch('https://connect.squareup.com/v2/payments', {
      method: 'POST',
      headers: {
        'Square-Version': '2024-02-28',
        'Authorization': `Bearer ${process.env.SQUARE_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        source_id: sourceId,
        idempotency_key: idempotencyKey,
        amount_money: {
          amount: amountCents,
          currency: 'USD',
        },
        location_id: process.env.SQUARE_LOCATION_ID,
        note: note || 'GBFPC Online Giving',
        statement_description_identifier: 'GBFPC GIVE',
        // Autocomplete = true means funds are captured immediately
        autocomplete: true,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      const errDetail = data.errors?.[0]?.detail || data.errors?.[0]?.code || 'Payment could not be processed.';
      console.error('Square payment error:', JSON.stringify(data.errors));
      return res.status(400).json({ error: errDetail });
    }

    return res.status(200).json({
      success: true,
      paymentId: data.payment.id,
      amountCharged: data.payment.amount_money.amount / 100,
    });

  } catch (err) {
    console.error('Server error:', err);
    return res.status(500).json({ error: 'Server error. Please try again.' });
  }
};
