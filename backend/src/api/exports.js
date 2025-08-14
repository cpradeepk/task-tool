import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import PDFDocument from 'pdfkit';
import ExcelJS from 'exceljs';
import { knex } from '../db/index.js';

const router = express.Router();
router.use(requireAuth);

router.get('/projects/:projectId/summary.pdf', async (req, res) => {
  const projectId = Number(req.params.projectId);
  const project = await knex('projects').where({ id: projectId }).first();
  const tasks = await knex('tasks').where({ project_id: projectId }).select('*');

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=project-${projectId}-summary.pdf`);
  const doc = new PDFDocument();
  doc.pipe(res);
  doc.fontSize(18).text(`Project Summary: ${project?.name ?? projectId}`);
  doc.moveDown();
  tasks.forEach(t => doc.fontSize(12).text(`- ${t.title} [${t.status ?? ''}]`));
  doc.end();
});

router.get('/projects/:projectId/summary.xlsx', async (req, res) => {
  const projectId = Number(req.params.projectId);
  const tasks = await knex('tasks').where({ project_id: projectId }).select('*');
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Tasks');
  ws.addRow(['ID','Title','Status','Priority','Start','Planned End','End']);
  tasks.forEach(t => ws.addRow([t.id, t.title, t.status, t.priority, t.start_date, t.planned_end_date, t.end_date]));
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.setHeader('Content-Disposition', `attachment; filename=project-${projectId}-summary.xlsx`);
  await wb.xlsx.write(res);
  res.end();
});

export default router;

