package com.imguomark.flightinquiry;


import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Font;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.util.*;
import java.util.regex.*;


public final class FlightInquiryApp {
  private final JTextField origin = new JTextField("SFO", 5), destination = new JTextField("PVG", 5);
  private final JTextArea results = new JTextArea();
  private final JLabel status = new JLabel("Enter a route and search for live aircraft activity.");
  private final HttpClient client = HttpClient.newHttpClient();
  public static void main(String[] args) { SwingUtilities.invokeLater(() -> new FlightInquiryApp().showWindow()); }
  private void showWindow() {
    JFrame f = new JFrame("Flight Inquiry"); f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE); f.setMinimumSize(new Dimension(720, 520));
    JPanel root = new JPanel(new BorderLayout(12, 12)); root.setBorder(new EmptyBorder(22,22,22,22));
    JLabel title = new JLabel("Find live aircraft activity"); title.setFont(title.getFont().deriveFont(Font.BOLD, 26f));
    JPanel header = new JPanel(new BorderLayout(4,4)); header.add(title, BorderLayout.NORTH); header.add(new JLabel("OpenSky state data only; ticket prices are not shown."), BorderLayout.SOUTH); root.add(header, BorderLayout.NORTH);
    JPanel search = new JPanel(new FlowLayout(FlowLayout.LEFT)); search.add(new JLabel("From")); search.add(origin); search.add(new JLabel("To")); search.add(destination); JButton go = new JButton("Search"); search.add(go); root.add(search, BorderLayout.CENTER);
    results.setEditable(false); results.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 13)); root.add(new JScrollPane(results), BorderLayout.CENTER); root.add(status, BorderLayout.SOUTH);
    go.addActionListener(e -> search(go)); f.setContentPane(root); f.pack(); f.setLocationByPlatform(true); f.setVisible(true);
  }
  private void search(JButton go) {
    String from=origin.getText().trim().toUpperCase(Locale.ROOT), to=destination.getText().trim().toUpperCase(Locale.ROOT);
    if (!from.matches("[A-Z]{3}") || !to.matches("[A-Z]{3}")) { status.setText("Use three-letter airport codes."); return; }
    go.setEnabled(false); status.setText("Searching OpenSky...");
    new SwingWorker<List<Flight>,Void>() {
      protected List<Flight> doInBackground() throws Exception { return "true".equalsIgnoreCase(System.getenv("FLIGHT_INQUIRY_MOCK")) ? mock(from,to) : openSky(); }
      protected void done() { go.setEnabled(true); try { render(get(),from,to); } catch(Exception e) { status.setText("Search failed: "+message(e)); } }
    }.execute();
  }
  private List<Flight> openSky() throws Exception {
